import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart' hide Response;

import '../../core/widgets/app_toast.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';
import '../../data/services/face_detector_service.dart';
import '../../data/services/face_embedder_service.dart';
import '../../data/services/face_scan_log_service.dart';

/// Face enrollment with a three-frame active-liveness challenge: neutral,
/// smiling, then neutral again. Requiring an expression change on demand blocks
/// a still photo. Laravel sends the three accepted frames to the private Python
/// recognition service and stores only the resulting encrypted template.
///
/// The preview is read as a stream and every accepted frame is persisted
/// directly; the final one also becomes the attendance selfie. No separate
/// still capture is needed on iOS.
class FaceEnrollController extends GetxController with WidgetsBindingObserver {
  final AvanaApi _api = AvanaApi();
  final FaceDetectorService _detector = FaceDetectorService();
  final FaceEmbedderService _embedder = Get.find<FaceEmbedderService>();
  final FaceScanLogService _scanLog = Get.find<FaceScanLogService>();

  CameraController? camera;

  final isReady = false.obs;
  final isBusy = false.obs;
  final enrolled = false.obs;
  final faceOk = false.obs; // a valid face for the current step is framed
  final hint = 'Menyiapkan kamera…'.obs;

  /// 0 = neutral, 1 = smile, 2 = neutral after the expression change.
  final step = 0.obs;

  final List<String> _capturePaths = [];

  /// Path of the most recent captured frame, reused as the clock-in selfie when
  /// enrollment feeds straight into an attendance punch.
  String? _lastShotPath;

  /// The camera this controller opened, kept for the rotation maths a stream
  /// frame needs.
  CameraDescription? _lens;

  /// Only used by the shutter fallback, for devices whose preview stream ML Kit
  /// cannot read.
  Timer? _scanTimer;

  bool _scanning = false;
  bool _done = false;
  bool _streaming = false;
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

  /// Consecutive failed scans for the current step. Purely informational —
  /// past a threshold we append a troubleshooting tip to the hint so a stuck
  /// user (e.g. an orientation edge case the capture-lock fix didn't cover)
  /// gets a next step instead of a hint that silently repeats forever.
  int _failStreak = 0;
  static const _stuckThreshold = 12; // ~16s at the 1300ms scan interval

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  Future<void> _boot() async {
    await _loadStatus();
    await _initCamera();
  }

  Future<void> _loadStatus() async {
    try {
      final res = await _api.faceStatus();
      enrolled.value = (res.data['data']?['enrolled'] as bool?) ?? false;
    } catch (_) {
      // Non-fatal: enrollment can still proceed.
    }
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
        // The camera plugin recommends a low preset while continuously
        // streaming. It is still well above MobileFaceNet's 112 px input and
        // avoids starving the iOS preview texture while ML Kit is processing.
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
      // iOS in particular can save takePicture() JPEGs without the EXIF
      // orientation matching the sensor's actual rotation, which throws off
      // ML Kit's head-pose (yaw/roll) reading and our own frame-centering
      // math independently — the scan gate then never agrees the face is
      // frontal/centered and enrollment loops forever. Locking capture
      // orientation forces a consistent, correctly-oriented JPEG on both
      // platforms.
      try {
        await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      } catch (_) {
        // Not fatal — some devices/plugin versions don't support locking;
        // scanning still proceeds with whatever orientation the platform
        // gives.
      }
      camera = controller;
      _lens = front;
      controller.addListener(_onCameraValueChanged);
      // Do not mount an empty iOS texture. The first streamed frame below is
      // the proof that AVFoundation is producing pixels, not just initialized.
      isReady.value = false;
      hint.value = 'Menyiapkan preview kamera…';
      await _startStream();
    } catch (e) {
      hint.value = 'Gagal membuka kamera. Beri izin kamera lalu coba lagi.';
      _log('blocked', 'camera_error', hint.value, {'error': e.toString()});
    }
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
        context: 'enroll',
        outcome: outcome,
        reason: reason,
        step: step.value,
        message: message,
        metrics: {...?metrics, 'fail_streak': _failStreak},
      ),
    );
  }

  /// Begin reading preview frames. Safe to call again after a pause.
  Future<void> _startStream({bool retried = false}) async {
    final cam = camera;
    if (cam == null || _streaming || _done) return;

    _consecutiveRejections = 0;
    if (_capturePaths.isEmpty) _trackingId = null;

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
        debugPrint('[FaceEnroll] image stream refused, retrying: $e');
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await _startStream(retried: true);

        return;
      }

      // Android retains the old shutter fallback. On iOS that fallback is the
      // behavior that disrupts the preview, so surface a stable error instead.
      debugPrint('[FaceEnroll] image stream unavailable: $e');
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

  /// Judge one preview frame for the current step and embed that same frame.
  Future<void> _onFrame(CameraImage image) async {
    if (_scanning || _done || _closed || _lifecyclePaused || isBusy.value) {
      return;
    }

    if (!isReady.value) {
      isReady.value = true;
      hint.value = _hintForStep();
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
        debugPrint('[FaceEnroll] unsupported stream format — falling back');
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

      if (faces.isEmpty || faces.length > 1) {
        _fail(
          faces.isEmpty
              ? 'Wajah tidak terdeteksi — pastikan seluruh wajah terlihat'
              : 'Pastikan hanya wajah Anda yang terlihat',
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
        _fail(_detector.hintForPositionRejection(positionRejection));

        return;
      }

      if (!_acceptTrackedFace(face.trackingId)) return;

      final rejection = _detector.rejectionOf(face);
      if (rejection != null) {
        _fail(_detector.hintForRejection(rejection));

        return;
      }

      // The expression challenge is judged on the preview too, so the employee
      // is told to smile (or stop) while they can still see themselves.
      final smiling = face.smilingProbability ?? 0;
      if (step.value != 1 && smiling > 0.5) {
        _fail('Wajah netral dulu (jangan senyum)');

        return;
      }
      if (step.value == 1 && smiling < 0.3) {
        _fail('Sekarang senyum 😊');

        return;
      }

      // Persist the accepted stream frame directly. Recognition happens in the
      // private Python service, so MobileFaceNet is no longer run on the phone.
      _consecutiveRejections = 0;
      _failStreak = 0;
      faceOk.value = true;
      isBusy.value = true;
      HapticFeedback.mediumImpact();
      hint.value = step.value == 1
          ? 'Senyum terekam…'
          : 'Wajah netral terekam…';

      final photoPath = await _embedder.saveCameraFrame(
        image,
        camera: lens,
        deviceOrientation: cam.value.deviceOrientation,
      );

      if (_done || _closed || _lifecyclePaused) return;

      if (photoPath == null) {
        debugPrint('[FaceEnroll] stream frame save failed');
        hint.value = 'Frame wajah gagal disimpan…';
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
        if (!_done) {
          await _startStream();
        }

        return;
      }

      debugPrint('[FaceEnroll] captured step=${step.value}');
      _log('ok', 'captured', null, {..._detector.metricsOf(face)});
      await _onStepDone(photoPath);
    } catch (e, st) {
      debugPrint('[FaceEnroll] frame error: $e\n$st');
      if (!_closed && !_done) {
        isBusy.value = false;
        faceOk.value = false;
      }
      _fail('Menyesuaikan kamera…');
      _log('fail', 'scan_error', hint.value, {'error': e.toString()});
    } finally {
      _scanning = false;
    }
  }

  Future<void> _onStepDone(String shotPath) async {
    _lastShotPath = shotPath;
    _capturePaths.add(shotPath);

    if (step.value < 2) {
      step.value++;
      faceOk.value = false;
      isBusy.value = false;
      hint.value = _hintForStep();

      return;
    }

    _done = true;
    await _stopStream();
    _scanning = false;
    await _submit();
  }

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
            : 'Pastikan hanya wajah Anda yang terlihat';

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

      final smiling = face.smilingProbability ?? 0;
      if (step.value != 1 && smiling > 0.5) {
        await _startStream();
        faceOk.value = false;
        isBusy.value = false;
        hint.value = 'Wajah netral dulu (jangan senyum)';

        return;
      }
      if (step.value == 1 && smiling < 0.3) {
        await _startStream();
        faceOk.value = false;
        isBusy.value = false;
        hint.value = 'Sekarang senyum 😊';

        return;
      }

      debugPrint('[FaceEnroll] OK via fallback step=${step.value}');
      _log('ok', 'captured', null, {..._detector.metricsOf(face)});
      await _onStepDone(shot.path);
    } catch (e, st) {
      debugPrint('[FaceEnroll] fallback error: $e\n$st');
      _log('fail', 'scan_error', hint.value, {'error': e.toString()});
      await _startStream();
      faceOk.value = false;
      isBusy.value = false;
      hint.value = 'Coba lagi — posisikan wajah di tengah bingkai';
    }
  }

  /// The old behaviour, kept for devices the stream does not work on: photograph
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

    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(
      const Duration(milliseconds: 1300),
      (_) => _scanOnce(),
    );
  }

  void _fail(String reason) {
    _consecutiveRejections++;
    _failStreak++;
    if (_consecutiveRejections >= _rejectionDebounce) {
      faceOk.value = false;
    }
    hint.value = _failStreak >= _stuckThreshold
        ? '$reason\nMasih gagal? Tutup & buka ulang halaman ini, atau '
              'pastikan pencahayaan cukup terang.'
        : reason;
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
      debugPrint('[FaceEnroll] step=${step.value} faces=${faces.length}');

      if (faces.isEmpty || faces.length > 1) {
        // Read the frame size even with no face: a capture whose dimensions
        // don't match what the preview shows is itself the diagnosis.
        await _detector.measureFrame(shot.path);
        final size = _detector.frameSize;
        _fail(
          faces.isEmpty
              ? 'Wajah tidak terdeteksi — dekatkan wajah'
              : 'Pastikan hanya wajah Anda yang terlihat',
        );
        _log('fail', faces.isEmpty ? 'no_face' : 'multi_face', hint.value, {
          'faces': faces.length,
          'detector': _detector.lastDetector,
          if (size != null) 'frame_width': size.$1,
          if (size != null) 'frame_height': size.$2,
          if (_detector.frameDecodeFailed) 'error': 'frame_decode_failed',
        });
        return;
      }
      final face = faces.first;
      // Learn the frame size before reading metrics, so the logged ratios are
      // populated even on the branches that return before the centering check.
      await _detector.measureFrame(shot.path);
      final metrics = {'faces': faces.length, ..._detector.metricsOf(face)};

      final positionRejection = await _detector.positionRejectionInFile(
        face,
        shot.path,
      );
      if (positionRejection != null) {
        _fail(_detector.hintForPositionRejection(positionRejection));
        _log('fail', positionRejection, hint.value, metrics);
        return;
      }

      final rejection = _detector.rejectionOf(face);
      if (rejection != null) {
        debugPrint(
          '[FaceEnroll] not frontal/open ($rejection) — '
          'yaw=${face.headEulerAngleY} roll=${face.headEulerAngleZ} '
          'leftEye=${face.leftEyeOpenProbability} '
          'rightEye=${face.rightEyeOpenProbability}',
        );
        _fail(_detector.hintForRejection(rejection));
        _log('fail', 'not_frontal', hint.value, {
          ...metrics,
          'error': rejection,
        });
        return;
      }
      final smiling = face.smilingProbability ?? 0;
      debugPrint('[FaceEnroll] smiling=$smiling');
      if (step.value != 1 && smiling > 0.5) {
        _fail('Wajah netral dulu (jangan senyum)');
        _log('fail', 'expression_neutral', hint.value, metrics);
        return;
      }
      if (step.value == 1 && smiling < 0.3) {
        _fail('Sekarang senyum 😊');
        _log('fail', 'expression_smile', hint.value, metrics);
        return;
      }

      // Good frame for this step -> record the JPEG for server enrollment.
      _consecutiveRejections = 0;
      _failStreak = 0;
      faceOk.value = true;
      isBusy.value = true;
      HapticFeedback.mediumImpact();
      hint.value = step.value == 1
          ? 'Senyum terekam…'
          : 'Wajah netral terekam…';

      debugPrint('[FaceEnroll] captured step=${step.value}');
      _log('ok', 'captured', null, {...metrics});
      await _onStepDone(shot.path);
    } catch (e, st) {
      debugPrint('[FaceEnroll] scan error: $e\n$st');
      faceOk.value = false;
      hint.value = 'Menyesuaikan kamera…';
      _log('fail', 'scan_error', hint.value, {'error': e.toString()});
    } finally {
      _scanning = false;
    }
  }

  Future<void> _submit() async {
    isBusy.value = true;
    hint.value = 'Mendaftarkan wajah…';
    try {
      final res = await _api.enrollFace(_capturePaths);
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        enrolled.value = true;
        await _shutdownCamera();
        // Reuse the final accepted frame for the immediate attendance punch.
        Get.back(result: {'photo': _lastShotPath});
      } else {
        final message = ApiClient.messageFrom(res, 'Gagal mendaftar wajah.');
        AppToast.error(message);
        _log('blocked', 'enroll_failed', message, {'error': 'HTTP $code'});
        await _resetAndResume();
      }
    } on DioException catch (e) {
      final message = ApiClient.errorMessage(e);
      AppToast.error(message);
      _log('blocked', 'enroll_failed', message, {'error': e.type.name});
      await _resetAndResume();
    } catch (e, st) {
      debugPrint('[FaceEnroll] submit error: $e\n$st');
      const message = 'Wajah gagal didaftarkan. Silakan coba lagi.';
      AppToast.error(message);
      _log('blocked', 'enroll_failed', message, {'error': e.toString()});
      await _resetAndResume();
    }
  }

  bool _acceptTrackedFace(int? trackingId) {
    if (trackingId == null) return true;
    final previousId = _trackingId;
    _trackingId = trackingId;
    if (previousId == null || previousId == trackingId) return true;

    _capturePaths.clear();
    _lastShotPath = null;
    step.value = 0;
    faceOk.value = false;
    isBusy.value = false;
    _consecutiveRejections = 0;
    _failStreak = 0;
    hint.value = 'Wajah berubah. Mulai ulang dengan wajah yang sama.';
    _log('fail', 'tracking_changed', hint.value, {
      'previous_tracking_id': previousId,
      'tracking_id': trackingId,
    });
    return false;
  }

  Future<void> _resetAndResume() async {
    _capturePaths.clear();
    _lastShotPath = null;
    _trackingId = null;
    step.value = 0;
    _done = false;
    faceOk.value = false;
    isBusy.value = false;
    _consecutiveRejections = 0;
    _failStreak = 0;
    _detector.resetFrame();
    hint.value = 'Ulangi — hadap kamera dengan wajah netral';
    await _startStream();
  }

  String _hintForStep() => switch (step.value) {
    0 => 'Hadap kamera dengan wajah netral',
    1 => 'Bagus! Sekarang senyum',
    _ => 'Kembali ke wajah netral',
  };

  /// Cancel enrollment and return nothing.
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
          debugPrint('[FaceEnroll] lifecycle error: $error\n$stackTrace');
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
      hint.value = _hintForStep();
      if (!_streaming) await _startStream();
      return;
    }

    _cameraShutdown = null;
    hint.value = 'Menyiapkan kembali kamera…';
    await _initCamera();
  }

  void _onCameraValueChanged() {
    final cam = camera;
    if (_closed || _done || _lifecyclePaused || cam == null) return;
    if (!cam.value.hasError) return;

    debugPrint(
      '[FaceEnroll] camera runtime error: ${cam.value.errorDescription}',
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
