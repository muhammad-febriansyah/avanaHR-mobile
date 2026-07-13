import 'package:get/get.dart';

import 'mss_recap_controller.dart';

class MssRecapBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MssRecapController>(() => MssRecapController());
  }
}
