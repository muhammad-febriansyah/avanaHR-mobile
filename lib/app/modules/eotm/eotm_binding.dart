import 'package:get/get.dart';

import 'eotm_controller.dart';

class EotmBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EotmController>(() => EotmController());
  }
}
