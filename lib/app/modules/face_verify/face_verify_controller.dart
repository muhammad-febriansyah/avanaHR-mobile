import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../data/services/active_liveness_service.dart';
import '../../data/services/face_detector_service.dart';
import '../../data/services/face_embedder_service.dart';
import '../../data/services/face_scan_log_service.dart';

/// Live face verification used at clock-in.
///
/// The preview is read as a stream, not photographed in a loop. Repeatedly
/// calling `takePicture()` blanked the preview white on every shot — several
/// times a second, the employee could not see their own face well enough to aim
/// it — and bought only one look per one-and-a-third seconds for the trouble.
/// Frames now arrive from the camera itself and are gated as they come. The
/// accepted frame is saved as the attendance selfie and Laravel sends it to the
/// private Python service for recognition, so iOS never switches capture output.
class FaceVerifyController extends GetxController with WidgetsBindingObserver {
  final FaceDetectorService _detector = FaceDetectorService();
  final FaceEmbedderService _embedder = Get.find<FaceEmbedderService>();
  final FaceScanLogService _scanLog = Get.find<FaceScanLogService>();
  late final ActiveLivenessGate _liveness;

  CameraController? camera;

  final isReady = false.obs;
  final isBusy = false.obs; // saving / finishing
  final faceOk = false.obs; // a valid face is framed right now
  final hint = 'Menyiapkan kamera…'.obs;
  final detectedFaceBoxes = <Rect>[].obs;

  /// The camera this controller opened, kept for the rotation maths a stream
  /// frame needs.
  CameraDescription? _lens;

  /// Only used by the shutter fallback, for devices whose preview stream ML
  /// Kit cannot read.
  Timer? _scanTimer;

  bool _scanning = false; // a frame is being analysed right now
  bool _done = false; // captured & returning
  bool _streaming = false; // the preview stream is running
  bool _closed = false;
  bool _lifecyclePaused = false;
  Future<void>? _cameraShutdown;
  Future<void>? _cameraInit;
  Future<void>? _cameraRecovery;
  Future<void> _lifecycleOperations = Future.value();

  int _consecutiveRejections = 0;
  int? _trackingId;
  static const _rejectionDebounce = 3;

  /// Frames arrive faster than they can be read; this drops the ones that come
  /// in while the previous is still being analysed, and keeps a floor between
  /// analyses so the phone is not pinned at full tilt for a whole scan.
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  static final _minFrameGap = Duration(
    milliseconds: Platform.isIOS ? 320 : 220,
  );

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _liveness = ActiveLivenessGate(
      challenge: math.Random.secure().nextBool()
          ? ActiveLivenessChallenge.blink
          : ActiveLivenessChallenge.turnHead,
      openEyeThreshold: Platform.isIOS ? 0.35 : 0.5,
    );
    _initCamera();
  }

  Future<void> _initCamera() {
    if (_closed || _done || _lifecyclePaused) return Future.value();
    final active = _cameraInit;
    if (active != null) return active;

    late final Future<void> future;
    future = _initCameraOnce().whenComplete(() {
      if (identical(_cameraInit, future)) _cameraInit = null;
    });
    _cameraInit = future;
    return future;
  }

  Future<void> _initCameraOnce() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        hint.value = 'Kamera tidak tersedia di perangkat ini.';
        _log('blocked', 'camera_unavailable', hint.value);
        return;
      }
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final controller = CameraController(
        front,
        // Keep iOS image streaming light enough that AVFoundation's preview
        // texture stays fed while accurate ML Kit detection runs.
        Platform.isIOS ? ResolutionPreset.low : ResolutionPreset.medium,
        enableAudio: false,
        // ML Kit reads NV21 on Android and BGRA on iOS. The camera's own
        // default on Android is three-plane YUV_420, which it will not take.
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (_closed || _done || _lifecyclePaused) {
        await controller.dispose();
        return;
      }
      // Keep photo flash disabled defensively. The reported iOS white blink is
      // caused by switching the capture session from streaming to a still, not
      // by a front-camera LED; successful scans therefore persist the stream
      // frame directly instead of calling takePicture().
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {
        // Not fatal — a camera without flash control still scans.
      }
      // The same lock enrollment applies. Without it the two scanners can hand
      // the embedder differently-oriented frames on the same phone — the
      // template is built from an upright face and the verification crop from a
      // rotated one, which lowers the match score against the person's own
      // enrolled face. Whatever orientation a device produces, both sides of
      // the comparison must be produced the same way.
      try {
        await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      } catch (_) {
        // Not fatal — some devices/plugin versions don't support locking.
      }
      camera = controller;
      _lens = front;
      controller.addListener(_onCameraValueChanged);
      // Keep the dark loading surface until AVFoundation has delivered an
      // actual frame. An initialized texture can still be temporarily empty.
      isReady.value = false;
      hint.value = 'Menyiapkan preview kamera…';
      await _startStream();
    } catch (e) {
      hint.value = 'Gagal membuka kamera. Beri izin kamera lalu coba lagi.';
      _log('blocked', 'camera_error', hint.value, {'error': e.toString()});
    }
  }

  void _reject(String msg) {
    _consecutiveRejections++;
    final livenessReset = _liveness.registerInvalidFrame();
    if (_consecutiveRejections >= _rejectionDebounce || livenessReset) {
      faceOk.value = false;
    }
    hint.value = msg;
  }

  /// Queue one scan attempt for the server-side face log.
  void _log(
    String outcome,
    String reason,
    String? message, [
    Map<String, dynamic>? metrics,
  ]) {
    _scanLog.record(
      FaceScanEvent(
        context: 'verify',
        outcome: outcome,
        reason: reason,
        message: message,
        metrics: metrics,
      ),
    );
  }

  /// Begin reading preview frames. Safe to call again after a pause.
  Future<void> _startStream({bool retried = false}) async {
    final cam = camera;
    if (cam == null || _streaming || _done) return;

    _consecutiveRejections = 0;
    _trackingId = null;
    if (!retried) _liveness.reset();

    try {
      await cam.startImageStream(_onFrame);
      _streaming = true;

      return;
    } catch (e) {
      // iOS refuses a stream started while the capture session is still
      // settling — right after `initialize()`, or after a page that had the
      // camera open has only just let go of it. One retry clears that, and
      // avoids dropping to the shutter loop, whose every photo blanks the
      // preview white.
      if (!retried) {
        debugPrint('[FaceVerify] image stream refused, retrying: $e');
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await _startStream(retried: true);

        return;
      }

      // Android retains the old shutter fallback. On iOS that fallback is the
      // behavior that disrupts the preview, so surface a stable error instead.
      debugPrint('[FaceVerify] image stream unavailable: $e');
      _log('fail', 'scan_error', null, {
        'error': 'stream_unavailable',
        'detail': e.toString(),
      });
      if (Platform.isIOS) {
        faceOk.value = false;
        isBusy.value = false;
        hint.value =
            'Stream kamera tidak dapat dibaca. Tutup halaman ini lalu coba lagi.';
        return;
      }
      _startShutterFallback();
    }
  }

  Future<void> _stopStream() async {
    final cam = camera;
    if (cam == null || !_streaming) return;

    _streaming = false;
    try {
      await cam.stopImageStream();
    } catch (_) {
      // Already stopped, or the camera is going away with the page.
    }
  }

  /// Judge one preview frame and persist that exact frame for server-side
  /// recognition and the attendance selfie.
  Future<void> _onFrame(CameraImage image) async {
    if (_scanning || _done || _closed || _lifecyclePaused || isBusy.value) {
      return;
    }

    if (!isReady.value) {
      isReady.value = true;
      hint.value = _liveness.currentHint;
      _lastFrameAt = DateTime.now();
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastFrameAt) < _minFrameGap) return;
    _lastFrameAt = now;

    final lens = _lens;
    final cam = camera;
    if (lens == null || cam == null) return;

    _scanning = true;
    try {
      final faces = await _detector.detectFrame(
        image,
        camera: lens,
        deviceOrientation: cam.value.deviceOrientation,
      );
      if (_closed || _done || _lifecyclePaused) return;

      // Null means the platform handed over a format ML Kit will not read.
      if (faces == null) {
        detectedFaceBoxes.clear();
        debugPrint('[FaceVerify] unsupported stream format — falling back');
        _log('fail', 'scan_error', null, {
          'error': 'unsupported_frame_format',
          'detail': _detector.lastFrameRejection,
        });
        await _stopStream();
        if (Platform.isIOS) {
          faceOk.value = false;
          isBusy.value = false;
          hint.value =
              'Format kamera iPhone tidak didukung. Perbarui aplikasi lalu coba lagi.';
          return;
        }
        _startShutterFallback();

        return;
      }

      detectedFaceBoxes.assignAll(
        _detector.overlayBoxesInFrame(
          faces,
          image.width,
          image.height,
          camera: lens,
          deviceOrientation: cam.value.deviceOrientation,
        ),
      );

      if (faces.isEmpty || faces.length > 1) {
        _reject(
          faces.isEmpty
              ? 'Wajah tidak terdeteksi — pastikan seluruh wajah terlihat'
              : 'Hanya wajah Anda yang boleh terlihat',
        );

        return;
      }

      final face = faces.first;
      final positionRejection = _detector.positionRejectionInFrame(
        face,
        image.width,
        image.height,
        camera: lens,
        deviceOrientation: cam.value.deviceOrientation,
      );
      if (positionRejection != null) {
        _reject(_detector.hintForPositionRejection(positionRejection));

        return;
      }

      if (!_acceptTrackedFace(face)) {
        return;
      }

      final observation = _livenessObservationOf(face);
      if (observation == null) {
        _reject(
          'Wajah kurang jelas - pastikan seluruh wajah terlihat dan cahaya cukup',
        );

        return;
      }

      _consecutiveRejections = 0;
      faceOk.value = true;
      final previousStage = _liveness.stage;
      final liveness = _liveness.observe(observation);
      hint.value = liveness.hint;
      if (liveness.timedOut) {
        _log('fail', 'liveness_timeout', liveness.hint, _liveness.evidence);
      }
      if (!liveness.passed) {
        if (previousStage != liveness.stage) {
          HapticFeedback.selectionClick();
        }
        return;
      }

      // The challenge ends on a neutral, open-eyed frame. Keep the regular
      // quality gate as a final safeguard before that exact frame is embedded.
      final rejection = _detector.rejectionOf(face);
      if (rejection != null) {
        _liveness.reset();
        _reject(_detector.hintForRejection(rejection));
        return;
      }

      // Save the accepted stream frame directly: no stop/restart, no shutter
      // flash, and no local recognition model competing with the iOS preview.
      hint.value = _liveness.currentHint;
      isBusy.value = true;
      HapticFeedback.mediumImpact();

      final photoPath = await _embedder.saveCameraFrame(
        image,
        camera: lens,
        deviceOrientation: cam.value.deviceOrientation,
      );

      if (_done || _closed || _lifecyclePaused) return;

      if (photoPath != null) {
        debugPrint('[FaceVerify] OK - frame saved');
        _log('ok', 'captured', null, {
          ..._detector.metricsOf(face),
          'liveness': _liveness.evidence,
        });
        _done = true;
        await _shutdownCamera();
        _scanning = false;
        Get.back(result: {'photo': photoPath, 'liveness': _liveness.evidence});

        return;
      }

      // Fallback: frame persistence failed -> try the old takePicture path.
      debugPrint(
        '[FaceVerify] stream frame save failed, falling back to still',
      );
      hint.value = 'Wajah terdeteksi — memverifikasi…';
      await _stopStream();
      if (Platform.isIOS) {
        faceOk.value = false;
        isBusy.value = false;
        hint.value =
            'Frame wajah gagal diproses. Tutup halaman ini lalu coba lagi.';
        _log('blocked', 'embed_failed', hint.value);
        return;
      }
      await _fallbackCapture();
    } catch (e, st) {
      debugPrint('[FaceVerify] frame error: $e\n$st');
      if (!_closed && !_done) {
        isBusy.value = false;
        faceOk.value = false;
        _liveness.reset();
      }
      _reject('Menyesuaikan kamera…');
      _log('fail', 'scan_error', hint.value, {'error': e.toString()});
    } finally {
      _scanning = false;
    }
  }

  /// The old behaviour, kept for devices the stream does not work on: photograph

  Future<void> _fallbackCapture() async {
    if (!Platform.isAndroid) {
      throw StateError('Still-capture fallback is disabled on iOS');
    }
    final cam = camera;
    if (cam == null || _done) return;

    try {
      final shot = await cam.takePicture();
      final faces = await _detector.detectFile(shot.path);

      if (faces.length != 1) {
        _log('fail', faces.isEmpty ? 'no_face' : 'multi_face', hint.value, {
          'faces': faces.length,
          'detector': _detector.lastDetector,
        });
        await _startStream();
        faceOk.value = false;
        isBusy.value = false;
        hint.value = faces.isEmpty
            ? 'Wajah tidak terdeteksi — pastikan seluruh wajah terlihat'
            : 'Hanya wajah Anda yang boleh terlihat';

        return;
      }

      final face = faces.first;
      final positionRejection = await _detector.positionRejectionInFile(
        face,
        shot.path,
      );
      final qualityRejection = _detector.rejectionOf(face);
      if (positionRejection != null || qualityRejection != null) {
        await _startStream();
        faceOk.value = false;
        isBusy.value = false;
        hint.value = positionRejection != null
            ? _detector.hintForPositionRejection(positionRejection)
            : _detector.hintForRejection(qualityRejection!);
        _log('fail', 'capture_quality', hint.value, {
          ..._detector.metricsOf(face),
          'error': positionRejection ?? qualityRejection,
        });
        return;
      }

      debugPrint('[FaceVerify] OK via fallback - frame saved');
      _log('ok', 'captured', null, {
        ..._detector.metricsOf(face),
        'liveness': _liveness.evidence,
      });
      _done = true;
      Get.back(result: {'photo': shot.path, 'liveness': _liveness.evidence});
    } catch (e, st) {
      debugPrint('[FaceVerify] fallback error: $e\n$st');
      _log('fail', 'scan_error', hint.value, {'error': e.toString()});
      await _startStream();
      faceOk.value = false;
      isBusy.value = false;
      hint.value = 'Coba lagi — posisikan wajah di tengah bingkai';
    }
  }

  /// the preview every so often and read the JPEG. Switching capture output can
  /// flash or freeze the iOS preview, so this fallback is Android-only.
  void _startShutterFallback() {
    if (!Platform.isAndroid) {
      faceOk.value = false;
      isBusy.value = false;
      hint.value =
          'Stream kamera tidak tersedia. Tutup halaman lalu coba lagi.';
      return;
    }
    if (_done) return;

    // A blink can be shorter than a still-capture cycle. Head movement remains
    // observable in this compatibility path and cannot be skipped.
    _liveness.reset(withChallenge: ActiveLivenessChallenge.turnHead);
    _trackingId = null;
    hint.value = _liveness.currentHint;
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(
      const Duration(milliseconds: 1300),
      (_) => _scanOnce(),
    );
  }

  Future<void> _scanOnce() async {
    if (!Platform.isAndroid) return;
    if (_scanning || _done || isBusy.value) return;
    final cam = camera;
    if (cam == null || !cam.value.isInitialized) return;

    _scanning = true;
    try {
      final shot = await cam.takePicture();
      final faces = await _detector.detectFile(shot.path);
      debugPrint('[FaceVerify] faces=${faces.length} path=${shot.path}');

      if (faces.isEmpty || faces.length > 1) {
        // Measure the frame even with no face: a capture whose dimensions
        // don't match the preview is itself the diagnosis.
        await _detector.measureFrame(shot.path);
        final size = _detector.frameSize;
        final message = faces.isEmpty
            ? 'Wajah tidak terdeteksi — dekatkan wajah'
            : 'Hanya wajah Anda yang boleh terlihat';
        _reject(message);
        _log('fail', faces.isEmpty ? 'no_face' : 'multi_face', message, {
          'faces': faces.length,
          'detector': _detector.lastDetector,
          if (size != null) 'frame_width': size.$1,
          if (size != null) 'frame_height': size.$2,
          if (_detector.frameDecodeFailed) 'error': 'frame_decode_failed',
        });
        return;
      }
      final face = faces.first;
      await _detector.measureFrame(shot.path);
      final metrics = {'faces': faces.length, ..._detector.metricsOf(face)};

      final positionRejection = await _detector.positionRejectionInFile(
        face,
        shot.path,
      );
      if (positionRejection != null) {
        final message = _detector.hintForPositionRejection(positionRejection);
        _reject(message);
        _log('fail', positionRejection, message, metrics);
        return;
      }

      final observation = _livenessObservationOf(face);
      if (observation == null) {
        _reject(
          'Wajah kurang jelas - pastikan seluruh wajah terlihat dan cahaya cukup',
        );
        return;
      }

      final previousStage = _liveness.stage;
      final liveness = _liveness.observe(observation);
      faceOk.value = true;
      hint.value = liveness.hint;
      if (liveness.timedOut) {
        _log('fail', 'liveness_timeout', liveness.hint, _liveness.evidence);
      }
      if (!liveness.passed) {
        if (previousStage != liveness.stage) {
          HapticFeedback.selectionClick();
        }
        return;
      }

      final rejection = _detector.rejectionOf(face);
      if (rejection != null) {
        _liveness.reset(withChallenge: ActiveLivenessChallenge.turnHead);
        faceOk.value = false;
        hint.value = _detector.hintForRejection(rejection);
        _log('fail', 'not_frontal', hint.value, {
          ...metrics,
          'error': rejection,
        });
        return;
      }

      // Good frame → verify.
      faceOk.value = true;
      hint.value = _liveness.currentHint;
      isBusy.value = true;
      HapticFeedback.mediumImpact();

      debugPrint('[FaceVerify] OK - still frame saved');
      _log('ok', 'captured', null, {
        ...metrics,
        'liveness': _liveness.evidence,
      });
      _done = true;
      _scanTimer?.cancel();
      Get.back(result: {'photo': shot.path, 'liveness': _liveness.evidence});
    } catch (e, st) {
      // Transient capture/detect error — keep scanning.
      debugPrint('[FaceVerify] scan error: $e\n$st');
      _reject('Menyesuaikan kamera…');
      _log('fail', 'scan_error', hint.value, {'error': e.toString()});
    } finally {
      _scanning = false;
    }
  }

  LivenessObservation? _livenessObservationOf(Face face) {
    final yaw = face.headEulerAngleY;
    final roll = face.headEulerAngleZ;
    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;
    if (yaw == null || roll == null || leftEye == null || rightEye == null) {
      return null;
    }

    return LivenessObservation(
      yaw: yaw,
      roll: roll,
      leftEyeOpen: leftEye,
      rightEyeOpen: rightEye,
    );
  }

  bool _acceptTrackedFace(Face face) {
    final trackingId = face.trackingId;
    if (trackingId == null) return true;
    final previousId = _trackingId;
    _trackingId = trackingId;
    if (previousId == null || previousId == trackingId) return true;

    _liveness.reset();
    _reject('Wajah berubah. Hadapkan wajah yang sama untuk mengulang.');
    _log('fail', 'tracking_changed', hint.value, {
      'previous_tracking_id': previousId,
      'tracking_id': trackingId,
    });
    return false;
  }

  /// Cancel and return nothing.
  Future<void> cancel() async {
    _scanTimer?.cancel();
    _done = true;
    await _shutdownCamera();
    Get.back();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_closed || _done) return;
    if (state == AppLifecycleState.resumed) {
      _lifecyclePaused = false;
      _queueLifecycleOperation(_resumeAfterLifecycle);
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _lifecyclePaused = true;
      isReady.value = false;
      faceOk.value = false;
      hint.value = 'Kamera dijeda…';
      _queueLifecycleOperation(_pauseForLifecycle);
    }
  }

  void _queueLifecycleOperation(Future<void> Function() operation) {
    _lifecycleOperations = _lifecycleOperations
        .then((_) => operation())
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('[FaceVerify] lifecycle error: $error\n$stackTrace');
        });
  }

  Future<void> _pauseForLifecycle() async {
    await _cameraInit;
    if (_closed) return;
    _scanTimer?.cancel();
    await _shutdownCamera();
  }

  Future<void> _resumeAfterLifecycle() async {
    await _cameraInit;
    await _cameraShutdown;
    if (_closed || _done || _lifecyclePaused) {
      return;
    }
    final cam = camera;
    if (cam != null && cam.value.isInitialized) {
      isReady.value = true;
      hint.value = _liveness.currentHint;
      if (!_streaming) await _startStream();
      return;
    }

    _cameraShutdown = null;
    _liveness.reset();
    hint.value = 'Menyiapkan kembali kamera…';
    await _initCamera();
  }

  void _onCameraValueChanged() {
    final cam = camera;
    if (_closed || _done || _lifecyclePaused || cam == null) return;
    if (!cam.value.hasError) return;

    debugPrint(
      '[FaceVerify] camera runtime error: ${cam.value.errorDescription}',
    );
    _log('fail', 'camera_runtime_error', null, {
      'error': cam.value.errorDescription,
    });
    _cameraRecovery ??= _recoverCamera().whenComplete(() {
      _cameraRecovery = null;
    });
  }

  Future<void> _recoverCamera() async {
    isReady.value = false;
    faceOk.value = false;
    isBusy.value = false;
    _liveness.reset();
    hint.value = 'Memulihkan kamera…';
    await _shutdownCamera();
    if (_closed || _done || _lifecyclePaused) return;

    _cameraShutdown = null;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await _initCamera();
  }

  Future<void> _shutdownCamera() => _cameraShutdown ??= _shutdownCameraOnce();

  Future<void> _shutdownCameraOnce() async {
    final cam = camera;
    if (cam == null) return;

    await _stopStream();
    cam.removeListener(_onCameraValueChanged);
    camera = null;
    _lens = null;
    isReady.value = false;
    try {
      await cam.dispose();
    } catch (_) {
      // The native session may already be gone while the route is closing.
    }
  }

  Future<void> _disposeResources() async {
    await _shutdownCamera();
    while (_scanning) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await _detector.dispose();
  }

  @override
  void onClose() {
    _closed = true;
    _done = true;
    WidgetsBinding.instance.removeObserver(this);
    _scanTimer?.cancel();
    // Send whatever the session recorded — a user who gives up and backs out is
    // exactly the case the log exists for.
    _scanLog.flush();
    unawaited(_disposeResources());
    super.onClose();
  }
}
