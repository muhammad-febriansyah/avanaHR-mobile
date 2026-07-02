import 'package:get/get.dart';

import 'leave_controller.dart';

class LeaveBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LeaveController>(() => LeaveController());
  }
}
