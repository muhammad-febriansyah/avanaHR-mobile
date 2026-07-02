import 'package:get/get.dart';

import 'wfh_controller.dart';

class WfhBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<WfhController>(() => WfhController());
  }
}
