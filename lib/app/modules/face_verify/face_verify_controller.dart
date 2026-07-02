import 'package:camera/camera.dart';
import 'package:get/get.dart';

import '../../core/widgets/app_toast.dart';
import '../../data/services/face_detector_service.dart';
import '../../data/services/face_embedder_service.dart';

/// One-shot face capture used at clock-in. Returns the 192-d embedding to the
/// caller via `Get.back(result: ...)`; enrollment already did the active
/// liveness, so here a single frontal, open-eyes frame is enough.
class FaceVerifyController extends GetxController {
  final FaceDetectorService _detector = FaceDetectorService();
  final FaceEmbedderService _embedder = Get.find<FaceEmbedderService>();

  CameraController? camera;

  final isReady = false.obs;
  final isBusy = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initCamera();
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
      if (!_detector.isFrontalOpenEyes(face)) {
        AppToast.warning('Hadapkan wajah lurus ke kamera dan buka mata.');

        return;
      }

      final embedding = await _embedder.embedFromFile(shot.path, face.boundingBox);
      if (embedding == null) {
        AppToast.error('Model wajah tidak tersedia. Hubungi admin.');

        return;
      }

      Get.back(result: embedding);
    } catch (_) {
      AppToast.error('Gagal memverifikasi wajah. Coba lagi.');
    } finally {
      isBusy.value = false;
    }
  }

  @override
  void onClose() {
    camera?.dispose();
    _detector.dispose();
    super.onClose();
  }
}
