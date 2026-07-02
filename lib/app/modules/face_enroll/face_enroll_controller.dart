import 'dart:io';
import 'dart:ui' show Rect;

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import '../../core/utils/vector_math.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';
import '../../data/services/face_detector_service.dart';
import '../../data/services/face_embedder_service.dart';

/// Face enrollment with a two-step active-liveness challenge: capture a neutral
/// face, then a smiling one. Requiring an expression change on demand blocks a
/// still photo held to the camera. The two embeddings are averaged into one
/// template and sent to the API (vector only, never the photo).
class FaceEnrollController extends GetxController {
  final AvanaApi _api = AvanaApi();
  final FaceDetectorService _detector = FaceDetectorService();
  final FaceEmbedderService _embedder = Get.find<FaceEmbedderService>();

  CameraController? camera;

  final isReady = false.obs;
  final isBusy = false.obs;
  final statusLoading = true.obs;
  final enrolled = false.obs;

  /// 0 = capture neutral face, 1 = capture smiling face.
  final step = 0.obs;

  final List<List<double>> _captures = [];

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
    statusLoading.value = true;
    try {
      final res = await _api.faceStatus();
      enrolled.value = (res.data['data']?['enrolled'] as bool?) ?? false;
    } catch (_) {
      // Non-fatal: enrollment can still proceed.
    }
    statusLoading.value = false;
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        AppToast.error('Kamera tidak tersedia di perangkat ini.');

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
    } catch (_) {
      AppToast.error('Gagal membuka kamera. Beri izin kamera lalu coba lagi.');
    }
  }

  String get instruction => step.value == 0
      ? 'Hadap kamera dengan wajah netral (jangan senyum), lalu tekan Ambil.'
      : 'Bagus! Sekarang senyum, lalu tekan Ambil.';

  Future<void> capture() async {
    final controller = camera;
    if (controller == null || !controller.value.isInitialized || isBusy.value) {
      return;
    }

    isBusy.value = true;
    try {
      final shot = await controller.takePicture();
      final faces = await _detector.detectFile(shot.path);

      if (faces.length != 1) {
        AppToast.warning('Pastikan hanya wajah Anda yang terlihat di kamera.');

        return;
      }

      final face = faces.first;
      if (!_isFrontal(face)) {
        AppToast.warning('Hadapkan wajah lurus ke kamera dan buka mata.');

        return;
      }

      final smiling = face.smilingProbability ?? 0;
      if (step.value == 0 && smiling > 0.5) {
        AppToast.warning('Wajah netral dulu ya (jangan senyum).');

        return;
      }
      if (step.value == 1 && smiling < 0.5) {
        AppToast.warning('Belum terdeteksi senyum. Coba senyum lebih lebar.');

        return;
      }

      final embedding = await _embedFrom(shot.path, face.boundingBox);
      if (embedding == null) {
        AppToast.error('Model wajah tidak tersedia. Hubungi admin.');

        return;
      }
      _captures.add(embedding);

      if (step.value == 0) {
        step.value = 1;
        AppToast.info('Wajah netral tersimpan. Sekarang senyum.');
      } else {
        await _submit();
      }
    } catch (_) {
      AppToast.error('Gagal mengambil wajah. Coba lagi.');
    } finally {
      isBusy.value = false;
    }
  }

  Future<List<double>?> _embedFrom(String path, Rect box) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return null;
    }

    return _embedder.embed(img.bakeOrientation(decoded), box);
  }

  bool _isFrontal(Face f) {
    final yaw = (f.headEulerAngleY ?? 0).abs();
    final roll = (f.headEulerAngleZ ?? 0).abs();
    final leftEye = f.leftEyeOpenProbability ?? 1;
    final rightEye = f.rightEyeOpenProbability ?? 1;

    return yaw <= 18 && roll <= 18 && leftEye > 0.4 && rightEye > 0.4;
  }

  Future<void> _submit() async {
    final template = VectorMath.averageNormalized(_captures);
    try {
      final res = await _api.enrollFace(template);
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        enrolled.value = true;
        AppToast.success(ApiClient.messageFrom(res, 'Wajah berhasil didaftarkan.'));
        Get.back(result: true);
      } else {
        AppToast.error(ApiClient.messageFrom(res, 'Gagal mendaftar wajah.'));
        _reset();
      }
    } on DioException catch (e) {
      AppToast.error(ApiClient.errorMessage(e));
      _reset();
    }
  }

  void _reset() {
    _captures.clear();
    step.value = 0;
  }

  @override
  void onClose() {
    camera?.dispose();
    _detector.dispose();
    super.onClose();
  }
}
