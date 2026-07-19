import 'package:get/get.dart';

import 'kasbon_controller.dart';

class KasbonBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<KasbonController>(() => KasbonController());
  }
}
