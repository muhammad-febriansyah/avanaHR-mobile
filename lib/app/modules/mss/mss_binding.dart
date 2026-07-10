import 'package:get/get.dart';

import 'mss_controller.dart';

class MssBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MssController>(() => MssController());
  }
}
