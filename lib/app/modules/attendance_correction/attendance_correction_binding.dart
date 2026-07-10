import 'package:get/get.dart';

import 'attendance_correction_controller.dart';

class AttendanceCorrectionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AttendanceCorrectionController>(() => AttendanceCorrectionController());
  }
}
