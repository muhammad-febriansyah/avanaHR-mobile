import 'package:get/get.dart';

import 'ai_tokens_controller.dart';

class AiTokensBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AiTokensController>(() => AiTokensController());
  }
}
