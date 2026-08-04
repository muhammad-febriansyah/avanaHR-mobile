import 'package:get/get.dart';

import 'two_factor_setup_controller.dart';

class TwoFactorSetupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TwoFactorSetupController>(() => TwoFactorSetupController());
  }
}
