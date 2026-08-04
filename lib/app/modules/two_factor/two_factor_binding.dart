import 'package:get/get.dart';

import 'two_factor_controller.dart';

class TwoFactorBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TwoFactorController>(() => TwoFactorController());
  }
}
