import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../data/services/face_detector_service.dart';
import '../../data/services/face_embedder_service.dart';
import '../../data/services/face_scan_log_service.dart';

/// Live face verification used at clock-in. The front camera runs continuously
/// and a scan loop grabs frames a few times a second, detecting a frontal,
/// open-eyes face automatically — no shutter button. On the first good frame it
/// embeds the face on-device and returns the 192-d vector via
/// `Get.back(result: ...)`.
class FaceVerifyController extends GetxController {
  final FaceDetectorService _detector = FaceDetectorService();
  final FaceEmbedderService _embedder = Get.find<FaceEmbedderService>();
  final FaceScanLogService _scanLog = Get.find<FaceScanLogService>();

  CameraController? camera;

  final isReady = false.obs;
  final isBusy = false.obs; // embedding / finishing
  final faceOk = false.obs; // a valid face is framed right now
  final hint = 'Menyiapkan kamera…'.obs;

  Timer? _scanTimer;
  bool _scanning = false; // a scan cycle is in flight
  bool _done = false; // captured & returning

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
      );
      await controller.initialize();
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
      isReady.value = true;
      hint.value = 'Posisikan wajah di dalam bingkai';
      _startScan();
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

  void _startScan() {
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
    Get.back();
  }

  @override
  void onClose() {
    _scanTimer?.cancel();
    // Send whatever the session recorded — a user who gives up and backs out is
    // exactly the case the log exists for.
    _scanLog.flush();
    camera?.dispose();
    _detector.dispose();
    super.onClose();
  }
}
