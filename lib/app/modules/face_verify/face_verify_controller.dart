import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../data/services/face_detector_service.dart';
import '../../data/services/face_embedder_service.dart';
import '../../data/services/face_scan_log_service.dart';

/// Live face verification used at clock-in.
///
/// The preview is read as a stream, not photographed in a loop. Repeatedly
/// calling `takePicture()` blanked the preview white on every shot — several
/// times a second, the employee could not see their own face well enough to aim
/// it — and bought only one look per one-and-a-third seconds for the trouble.
/// Frames now arrive from the camera itself, are gated as they come, and a
/// single still is taken at the end: the authoritative frame the embedding is
/// computed from, checked once more before it counts.
class FaceVerifyController extends GetxController {
  final FaceDetectorService _detector = FaceDetectorService();
  final FaceEmbedderService _embedder = Get.find<FaceEmbedderService>();
  final FaceScanLogService _scanLog = Get.find<FaceScanLogService>();

  CameraController? camera;

  final isReady = false.obs;
  final isBusy = false.obs; // embedding / finishing
  final faceOk = false.obs; // a valid face is framed right now
  final hint = 'Menyiapkan kamera…'.obs;

  /// The camera this controller opened, kept for the rotation maths a stream
  /// frame needs.
  CameraDescription? _lens;

  /// Only used by the shutter fallback, for devices whose preview stream ML
  /// Kit cannot read.
  Timer? _scanTimer;

  bool _scanning = false; // a frame is being analysed right now
  bool _done = false; // captured & returning
  bool _streaming = false; // the preview stream is running

  /// Frames arrive faster than they can be read; this drops the ones that come
  /// in while the previous is still being analysed, and keeps a floor between
  /// analyses so the phone is not pinned at full tilt for a whole scan.
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const _minFrameGap = Duration(milliseconds: 220);

  @override
  void onInit() {
    super.onInit();
    _initCamera();
  }

  Future<void> _initCamera() async {
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
        ResolutionPreset.medium,
        enableAudio: false,
        // ML Kit reads NV21 on Android and BGRA on iOS. The camera's own
        // default on Android is three-plane YUV_420, which it will not take.
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      // The plugin's default is FlashMode.auto, and an iPhone front camera has
      // no lamp — it flashes the *screen* white to light the face instead. In a
      // dim room that fires on every still, which employees read as the app
      // breaking. Nothing here needs a flash: the scan gates reject a face too
      // dark to read and ask for better light in words.
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
      isReady.value = true;
      hint.value = 'Posisikan wajah di dalam bingkai';
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

      // A device that refuses the stream still deserves a working scan, so fall
      // back to the old shutter loop rather than leaving a dead camera.
      debugPrint('[FaceVerify] image stream unavailable: $e');
      _log('fail', 'scan_error', null, {
        'error': 'stream_unavailable',
        'detail': e.toString(),
      });
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

  /// Judge one preview frame. Cheap checks only — the still taken afterwards is
  /// what an embedding is actually computed from.
  Future<void> _onFrame(CameraImage image) async {
    if (_scanning || _done || isBusy.value) return;

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

      // Null means the platform handed over a format ML Kit will not read.
      // Nothing about the frame is knowable, so stop guessing and go back to
      // the shutter loop, which decodes a JPEG instead.
      if (faces == null) {
        debugPrint('[FaceVerify] unsupported stream format — falling back');
        _log('fail', 'scan_error', null, {
          'error': 'unsupported_frame_format',
          'detail': _detector.lastFrameRejection,
        });
        await _stopStream();
        _startShutterFallback();

        return;
      }

      if (faces.isEmpty || faces.length > 1) {
        faceOk.value = false;
        hint.value = faces.isEmpty
            ? 'Wajah tidak terdeteksi — pastikan seluruh wajah terlihat'
            : 'Hanya wajah Anda yang boleh terlihat';

        return;
      }

      final face = faces.first;
      if (!_detector.isCloseEnoughInFrame(face, image.width, image.height)) {
        faceOk.value = false;
        hint.value = 'Wajah terlalu jauh — dekatkan ke kamera';

        return;
      }

      final rejection = _detector.rejectionOf(face);
      if (rejection != null) {
        faceOk.value = false;
        hint.value = _detector.hintForRejection(rejection);

        return;
      }

      // Compute the embedding from the stream frame directly — no stop/restart,
      // no shutter flash, no re-check race against a separate still photo.
      faceOk.value = true;
      hint.value = 'Wajah terdeteksi — memverifikasi…';
      isBusy.value = true;
      HapticFeedback.mediumImpact();

      final embedding = await _embedder.embedFromCameraImage(
        image,
        face.boundingBox,
        leftEye: _detector.leftEyeOf(face),
        rightEye: _detector.rightEyeOf(face),
        camera: lens,
        deviceOrientation: cam.value.deviceOrientation,
      );

      if (embedding != null) {
        debugPrint('[FaceVerify] OK — embedding len=${embedding.length}');
        _log('ok', 'captured', null, {
          ..._detector.metricsOf(face),
          'embedding_dimensions': embedding.length,
        });
        _done = true;
        await _stopStream();
        final shot =
            camera?.value.isInitialized == true ? await camera!.takePicture() : null;
        _scanning = false;
        Get.back(result: {
          'embedding': embedding,
          'photo': shot?.path,
        });

        return;
      }

      // Fallback: stream embedding failed → try the old takePicture path.
      debugPrint('[FaceVerify] stream embed failed, falling back to still');
      hint.value = 'Wajah terdeteksi — memverifikasi…';
      await _stopStream();
      await _fallbackCapture();
    } catch (e, st) {
      debugPrint('[FaceVerify] frame error: $e\n$st');
    } finally {
      _scanning = false;
    }
  }

  /// The old behaviour, kept for devices the stream does not work on: photograph

  Future<void> _fallbackCapture() async {
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
      final embedding = await _embedder.embedFromFile(
        shot.path,
        face.boundingBox,
        leftEye: _detector.leftEyeOf(face),
        rightEye: _detector.rightEyeOf(face),
      );

      if (embedding == null) {
        _log('blocked', 'embed_failed', hint.value, _detector.metricsOf(face));
        faceOk.value = false;
        isBusy.value = false;
        hint.value = 'Model wajah tidak tersedia. Hubungi admin.';

        return;
      }

      debugPrint('[FaceVerify] OK via fallback — embedding len=${embedding.length}');
      _log('ok', 'captured', null, {
        ..._detector.metricsOf(face),
        'embedding_dimensions': embedding.length,
      });
      _done = true;
      Get.back(result: {'embedding': embedding, 'photo': shot.path});
    } catch (e, st) {
      debugPrint('[FaceVerify] fallback error: $e\n$st');
      _log('fail', 'scan_error', hint.value, {'error': e.toString()});
      await _startStream();
      faceOk.value = false;
      isBusy.value = false;
      hint.value = 'Coba lagi — posisikan wajah di tengah bingkai';
    }
  }

  /// the preview every so often and read the JPEG. It flashes the screen white
  /// on every shot, which is why it is no longer the default.
  void _startShutterFallback() {
    if (_done) return;

    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(
      const Duration(milliseconds: 1300),
      (_) => _scanOnce(),
    );
  }

  Future<void> _scanOnce() async {
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
        faceOk.value = false;
        hint.value = faces.isEmpty
            ? 'Wajah tidak terdeteksi — dekatkan wajah'
            : 'Hanya wajah Anda yang boleh terlihat';
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
      await _detector.measureFrame(shot.path);
      final metrics = {'faces': faces.length, ..._detector.metricsOf(face)};

      if (!_detector.isCloseEnough(face)) {
        faceOk.value = false;
        hint.value = 'Wajah terlalu jauh — dekatkan ke kamera';
        _log('fail', 'too_far', hint.value, metrics);
        return;
      }

      final rejection = _detector.rejectionOf(face);
      if (rejection != null) {
        debugPrint(
          '[FaceVerify] not frontal/open ($rejection) — '
          'yaw=${face.headEulerAngleY} roll=${face.headEulerAngleZ} '
          'leftEye=${face.leftEyeOpenProbability} '
          'rightEye=${face.rightEyeOpenProbability}',
        );
        faceOk.value = false;
        hint.value = _detector.hintForRejection(rejection);
        _log('fail', 'not_frontal', hint.value, {
          ...metrics,
          'error': rejection,
        });
        return;
      }
      if (!await _detector.isCentered(face, shot.path)) {
        faceOk.value = false;
        hint.value = 'Posisikan wajah di tengah bingkai';
        _log('fail', 'not_centered', hint.value, metrics);
        return;
      }

      // Good frame → verify.
      faceOk.value = true;
      hint.value = 'Wajah terdeteksi — memverifikasi…';
      isBusy.value = true;
      HapticFeedback.mediumImpact();

      final embedding = await _embedder.embedFromFile(
        shot.path,
        face.boundingBox,
        leftEye: _detector.leftEyeOf(face),
        rightEye: _detector.rightEyeOf(face),
      );
      if (embedding == null) {
        debugPrint('[FaceVerify] embedding null (see [FaceEmbedder] logs)');
        isBusy.value = false;
        faceOk.value = false;
        hint.value = 'Model wajah tidak tersedia. Hubungi admin.';
        _log('blocked', 'embed_failed', hint.value, metrics);
        return;
      }

      debugPrint('[FaceVerify] OK — embedding len=${embedding.length}');
      _log('ok', 'captured', null, {
        ...metrics,
        'embedding_dimensions': embedding.length,
      });
      _done = true;
      _scanTimer?.cancel();
      // Return the embedding (for server-side verification) AND the captured
      // frame path so the clock action can upload it as the attendance selfie.
      Get.back(result: {'embedding': embedding, 'photo': shot.path});
    } catch (e, st) {
      // Transient capture/detect error — keep scanning.
      debugPrint('[FaceVerify] scan error: $e\n$st');
      faceOk.value = false;
      hint.value = 'Menyesuaikan kamera…';
      _log('fail', 'scan_error', hint.value, {'error': e.toString()});
    } finally {
      _scanning = false;
    }
  }

  /// Cancel and return nothing.
  void cancel() {
    _scanTimer?.cancel();
    _done = true;
    Get.back();
  }

  @override
  void onClose() {
    _scanTimer?.cancel();
    // Send whatever the session recorded — a user who gives up and backs out is
    // exactly the case the log exists for.
    _scanLog.flush();
    if (_streaming) {
      _streaming = false;
      unawaited(
        camera?.stopImageStream().catchError((_) {}) ?? Future.value(),
      );
    }
    camera?.dispose();
    _detector.dispose();
    super.onClose();
  }
}
