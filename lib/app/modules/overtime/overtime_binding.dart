import 'package:get/get.dart';

import 'overtime_controller.dart';

class OvertimeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<OvertimeController>(() => OvertimeController());
  }
}
