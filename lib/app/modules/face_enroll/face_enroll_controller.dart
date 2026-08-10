import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;

import '../../core/utils/vector_math.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';
import '../../data/services/face_detector_service.dart';
import '../../data/services/face_embedder_service.dart';
import '../../data/services/face_scan_log_service.dart';

/// Face enrollment with a two-step active-liveness challenge: capture a neutral
/// face, then a smiling one. Requiring an expression change on demand blocks a
/// still photo. The two embeddings are averaged into one template and sent to
/// the API (vector only, never a photo).
///
/// The preview is read as a stream and only the frame that finally passes is
/// photographed. Photographing in a loop instead blanked the screen white on
/// every shot, several times a second — which left the employee unable to see
/// the face they were being asked to position.
class FaceEnrollController extends GetxController {
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

  /// 0 = capture neutral face, 1 = capture smiling face.
  final step = 0.obs;

  final List<List<double>> _captures = [];

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

  /// Frames arrive faster than they can be read; this drops the ones that come
  /// in while the previous is still being analysed, and keeps a floor between
  /// analyses so the phone is not pinned at full tilt for a whole scan.
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const _minFrameGap = Duration(milliseconds: 220);

  /// Consecutive failed scans for the current step. Purely informational —
  /// past a threshold we append a troubleshooting tip to the hint so a stuck
  /// user (e.g. an orientation edge case the capture-lock fix didn't cover)
  /// gets a next step instead of a hint that silently repeats forever.
  int _failStreak = 0;
  static const _stuckThreshold = 12; // ~16s at the 1300ms scan interval

  @override
  void onInit() {
    super.onInit();
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
      isReady.value = true;
      hint.value = 'Hadap kamera dengan wajah netral';
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
  Future<void> _startStream() async {
    final cam = camera;
    if (cam == null || _streaming || _done) return;

    try {
      await cam.startImageStream(_onFrame);
      _streaming = true;
    } catch (e) {
      // A device that refuses the stream still deserves a working enrolment, so
      // fall back to the old shutter loop rather than leaving a dead camera.
      debugPrint('[FaceEnroll] image stream unavailable: $e');
      _log('fail', 'scan_error', null, {'error': 'stream_unavailable'});
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

  /// Judge one preview frame for the current step. Cheap checks only — the
  /// still taken afterwards is what an embedding is actually computed from.
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
      if (faces == null) {
        debugPrint('[FaceEnroll] unsupported stream format — falling back');
        _log('fail', 'scan_error', null, {'error': 'unsupported_frame_format'});
        await _stopStream();
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
      if (!_detector.isCloseEnoughInFrame(face, image.width, image.height)) {
        _fail('Wajah terlalu jauh — dekatkan ke kamera');

        return;
      }

      final rejection = _detector.rejectionOf(face);
      if (rejection != null) {
        _fail(_detector.hintForRejection(rejection));

        return;
      }

      // The expression challenge is judged on the preview too, so the employee
      // is told to smile (or stop) while they can still see themselves.
      final smiling = face.smilingProbability ?? 0;
      if (step.value == 0 && smiling > 0.5) {
        _fail('Wajah netral dulu (jangan senyum)');

        return;
      }
      if (step.value == 1 && smiling < 0.3) {
        _fail('Sekarang senyum 😊');

        return;
      }

      // Compute the embedding from the stream frame directly — no stop/restart,
      // no shutter flash, no re-check race against a separate still photo.
      _failStreak = 0;
      faceOk.value = true;
      isBusy.value = true;
      HapticFeedback.mediumImpact();
      hint.value = step.value == 0
          ? 'Wajah netral terekam…'
          : 'Senyum terekam…';

      final embedding = await _embedder.embedFromCameraImage(
        image,
        face.boundingBox,
        leftEye: _detector.leftEyeOf(face),
        rightEye: _detector.rightEyeOf(face),
        camera: lens,
        deviceOrientation: cam.value.deviceOrientation,
      );

      if (embedding == null) {
        debugPrint('[FaceEnroll] stream embed failed, falling back to still');
        hint.value = step.value == 0
            ? 'Wajah netral terekam…'
            : 'Senyum terekam…';
        await _stopStream();
        await _fallbackCapture();
        if (!_done) {
          await _startStream();
        }

        return;
      }

      debugPrint(
        '[FaceEnroll] captured step=${step.value} len=${embedding.length}',
      );
      _log('ok', 'captured', null, {
        ..._detector.metricsOf(face),
        'embedding_dimensions': embedding.length,
      });
      _captures.add(embedding);
      _lastShotPath = null;

      if (step.value == 0) {
        step.value = 1;
        faceOk.value = false;
        isBusy.value = false;
        hint.value = 'Bagus! Sekarang senyum 😊';

        return;
      }

      _done = true;
      await _stopStream();
      try {
        if (camera?.value.isInitialized == true) {
          final shot = await camera!.takePicture();
          _lastShotPath = shot.path;
        }
      } catch (_) {
        // Selfie is best-effort; embedding already captured.
      }
      _scanning = false;
      await _submit();
    } catch (e, st) {
      debugPrint('[FaceEnroll] frame error: $e\n$st');
    } finally {
      _scanning = false;
    }
  }

  void _onStepDone(List<double> embedding, [String? shotPath]) {
    _lastShotPath = shotPath;
    _captures.add(embedding);

    if (step.value == 0) {
      step.value = 1;
      faceOk.value = false;
      isBusy.value = false;
      hint.value = 'Bagus! Sekarang senyum 😊';

      return;
    }

    _done = true;
    _submit();
  }

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
            : 'Pastikan hanya wajah Anda yang terlihat';

        return;
      }

      final face = faces.first;
      final smiling = face.smilingProbability ?? 0;
      if (step.value == 0 && smiling > 0.5) {
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

      debugPrint('[FaceEnroll] OK via fallback step=${step.value} len=${embedding.length}');
      _log('ok', 'captured', null, {
        ..._detector.metricsOf(face),
        'embedding_dimensions': embedding.length,
      });
      _onStepDone(embedding, shot.path);
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

  void _fail(String reason) {
    faceOk.value = false;
    _failStreak++;
    hint.value = _failStreak >= _stuckThreshold
        ? '$reason\nMasih gagal? Tutup & buka ulang halaman ini, atau '
              'pastikan pencahayaan cukup terang.'
        : reason;
  }

  Future<void> _scanOnce() async {
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

      if (!_detector.isCloseEnough(face)) {
        _fail('Wajah terlalu jauh — dekatkan ke kamera');
        _log('fail', 'too_far', hint.value, metrics);
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
      if (!await _detector.isCentered(face, shot.path)) {
        _fail('Posisikan wajah di tengah bingkai');
        _log('fail', 'not_centered', hint.value, metrics);
        return;
      }

      final smiling = face.smilingProbability ?? 0;
      debugPrint('[FaceEnroll] smiling=$smiling');
      if (step.value == 0 && smiling > 0.5) {
        _fail('Wajah netral dulu (jangan senyum)');
        _log('fail', 'expression_neutral', hint.value, metrics);
        return;
      }
      if (step.value == 1 && smiling < 0.3) {
        _fail('Sekarang senyum 😊');
        _log('fail', 'expression_smile', hint.value, metrics);
        return;
      }

      // Good frame for this step → embed & record.
      _failStreak = 0;
      faceOk.value = true;
      isBusy.value = true;
      HapticFeedback.mediumImpact();
      hint.value = step.value == 0
          ? 'Wajah netral terekam…'
          : 'Senyum terekam…';

      final embedding = await _embedder.embedFromFile(
        shot.path,
        face.boundingBox,
        leftEye: _detector.leftEyeOf(face),
        rightEye: _detector.rightEyeOf(face),
      );
      if (embedding == null) {
        debugPrint('[FaceEnroll] embedding null (see [FaceEmbedder] logs)');
        isBusy.value = false;
        faceOk.value = false;
        hint.value = 'Model wajah tidak tersedia. Hubungi admin.';
        _log('blocked', 'embed_failed', hint.value, metrics);
        return;
      }
      debugPrint(
        '[FaceEnroll] captured step=${step.value} len=${embedding.length}',
      );
      _log('ok', 'captured', null, {
        ...metrics,
        'embedding_dimensions': embedding.length,
      });
      _captures.add(embedding);
      _lastShotPath = shot.path;

      if (step.value == 0) {
        step.value = 1;
        faceOk.value = false;
        isBusy.value = false;
        hint.value = 'Bagus! Sekarang senyum 😊';
      } else {
        _done = true;
        _scanTimer?.cancel();
        await _submit();
      }
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
    final template = VectorMath.averageNormalized(_captures);
    try {
      final res = await _api.enrollFace(template);
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        enrolled.value = true;
        // Hand the freshly registered template + last frame back so the caller
        // can clock in immediately without a second face scan.
        Get.back(result: {'embedding': template, 'photo': _lastShotPath});
      } else {
        final message = ApiClient.messageFrom(res, 'Gagal mendaftar wajah.');
        AppToast.error(message);
        _log('blocked', 'enroll_failed', message, {'error': 'HTTP $code'});
        _resetAndResume();
      }
    } on DioException catch (e) {
      final message = ApiClient.errorMessage(e);
      AppToast.error(message);
      _log('blocked', 'enroll_failed', message, {'error': e.type.name});
      _resetAndResume();
    }
  }

  Future<void> _resetAndResume() async {
    _captures.clear();
    step.value = 0;
    _done = false;
    faceOk.value = false;
    isBusy.value = false;
    _failStreak = 0;
    _detector.resetFrame();
    hint.value = 'Ulangi — hadap kamera dengan wajah netral';
  }

  /// Cancel enrollment and return nothing.
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
