import 'package:get/get.dart';

import 'payslip_controller.dart';

class PayslipBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PayslipController>(() => PayslipController());
  }
}
