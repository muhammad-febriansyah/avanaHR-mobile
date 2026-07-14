import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../data/services/face_detector_service.dart';
import '../../data/services/face_embedder_service.dart';

/// Live face verification used at clock-in. The front camera runs continuously
/// and a scan loop grabs frames a few times a second, detecting a frontal,
/// open-eyes face automatically — no shutter button. On the first good frame it
/// embeds the face on-device and returns the 192-d vector via
/// `Get.back(result: ...)`.
class FaceVerifyController extends GetxController {
  final FaceDetectorService _detector = FaceDetectorService();
  final FaceEmbedderService _embedder = Get.find<FaceEmbedderService>();

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
      hint.value = 'Posisikan wajah di dalam bingkai';
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

      if (faces.isEmpty) {
        faceOk.value = false;
        hint.value = 'Wajah tidak terdeteksi — dekatkan wajah';
        return;
      }
      if (faces.length > 1) {
        faceOk.value = false;
        hint.value = 'Hanya wajah Anda yang boleh terlihat';
        return;
      }
      final face = faces.first;
      if (!_detector.isFrontalOpenEyes(face)) {
        faceOk.value = false;
        hint.value = 'Hadapkan wajah lurus & buka mata';
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
      );
      if (embedding == null) {
        isBusy.value = false;
        faceOk.value = false;
        hint.value = 'Model wajah tidak tersedia. Hubungi admin.';
        return;
      }

      _done = true;
      _scanTimer?.cancel();
      // Return the embedding (for server-side verification) AND the captured
      // frame path so the clock action can upload it as the attendance selfie.
      Get.back(result: {'embedding': embedding, 'photo': shot.path});
    } catch (_) {
      // Transient capture/detect error — keep scanning.
      faceOk.value = false;
      hint.value = 'Menyesuaikan kamera…';
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
    camera?.dispose();
    _detector.dispose();
    super.onClose();
  }
}
