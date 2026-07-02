import 'package:get/get.dart';

import '../../data/services/face_embedder_service.dart';
import 'face_verify_controller.dart';

class FaceVerifyBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<FaceEmbedderService>()) {
      Get.put(FaceEmbedderService(), permanent: true);
    }
    Get.lazyPut<FaceVerifyController>(() => FaceVerifyController());
  }
}
