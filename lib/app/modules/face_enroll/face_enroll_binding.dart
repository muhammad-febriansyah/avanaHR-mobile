import 'package:get/get.dart';

import '../../data/services/face_embedder_service.dart';
import 'face_enroll_controller.dart';

class FaceEnrollBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<FaceEmbedderService>()) {
      Get.put(FaceEmbedderService(), permanent: true);
    }
    Get.lazyPut<FaceEnrollController>(() => FaceEnrollController());
  }
}
