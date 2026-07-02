import 'package:get/get.dart';

import 'shift_swap_controller.dart';

class ShiftSwapBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ShiftSwapController>(() => ShiftSwapController());
  }
}
