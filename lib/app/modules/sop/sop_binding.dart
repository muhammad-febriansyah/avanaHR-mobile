import 'package:get/get.dart';

import 'sop_controller.dart';

class SopBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SopController>(() => SopController());
  }
}
