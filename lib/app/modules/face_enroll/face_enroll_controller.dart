import 'dart:async';

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

/// Face enrollment with a two-step active-liveness challenge: capture a neutral
/// face, then a smiling one. The front camera runs continuously and a scan loop
/// auto-captures the right frame for each step (no shutter button). Requiring an
/// expression change on demand blocks a still photo. The two embeddings are
/// averaged into one template and sent to the API (vector only, never a photo).
class FaceEnrollController extends GetxController {
  final AvanaApi _api = AvanaApi();
  final FaceDetectorService _detector = FaceDetectorService();
  final FaceEmbedderService _embedder = Get.find<FaceEmbedderService>();

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

  Timer? _scanTimer;
  bool _scanning = false;
  bool _done = false;

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
      camera = controller;
      isReady.value = true;
      hint.value = 'Hadap kamera dengan wajah netral';
      _startScan();
    } catch (_) {
      hint.value = 'Gagal membuka kamera. Beri izin kamera lalu coba lagi.';
    }
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
      debugPrint('[FaceEnroll] step=${step.value} faces=${faces.length}');

      if (faces.length != 1) {
        faceOk.value = false;
        hint.value = 'Pastikan hanya wajah Anda yang terlihat';
        return;
      }
      final face = faces.first;
      if (!_detector.isFrontalOpenEyes(face)) {
        debugPrint(
          '[FaceEnroll] not frontal/open — yaw=${face.headEulerAngleY} '
          'roll=${face.headEulerAngleZ} leftEye=${face.leftEyeOpenProbability} '
          'rightEye=${face.rightEyeOpenProbability}',
        );
        faceOk.value = false;
        hint.value = 'Hadapkan wajah lurus & buka mata';
        return;
      }

      final smiling = face.smilingProbability ?? 0;
      debugPrint('[FaceEnroll] smiling=$smiling');
      if (step.value == 0 && smiling > 0.5) {
        faceOk.value = false;
        hint.value = 'Wajah netral dulu (jangan senyum)';
        return;
      }
      if (step.value == 1 && smiling < 0.5) {
        faceOk.value = false;
        hint.value = 'Sekarang senyum 😊';
        return;
      }

      // Good frame for this step → embed & record.
      faceOk.value = true;
      isBusy.value = true;
      HapticFeedback.mediumImpact();
      hint.value = step.value == 0
          ? 'Wajah netral terekam…'
          : 'Senyum terekam…';

      final embedding = await _embedder.embedFromFile(
        shot.path,
        face.boundingBox,
      );
      if (embedding == null) {
        debugPrint('[FaceEnroll] embedding null (see [FaceEmbedder] logs)');
        isBusy.value = false;
        faceOk.value = false;
        hint.value = 'Model wajah tidak tersedia. Hubungi admin.';
        return;
      }
      debugPrint(
        '[FaceEnroll] captured step=${step.value} len=${embedding.length}',
      );
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
        AppToast.error(ApiClient.messageFrom(res, 'Gagal mendaftar wajah.'));
        _resetAndResume();
      }
    } on DioException catch (e) {
      AppToast.error(ApiClient.errorMessage(e));
      _resetAndResume();
    }
  }

  void _resetAndResume() {
    _captures.clear();
    step.value = 0;
    _done = false;
    faceOk.value = false;
    isBusy.value = false;
    hint.value = 'Ulangi — hadap kamera dengan wajah netral';
    _startScan();
  }

  /// Cancel enrollment and return nothing.
  void cancel() {
    _scanTimer?.cancel();
    Get.back();
  }

  @override
  void onClose() {
    _scanTimer?.cancel();
    camera?.dispose();
    _detector.dispose();
    super.onClose();
  }
}
