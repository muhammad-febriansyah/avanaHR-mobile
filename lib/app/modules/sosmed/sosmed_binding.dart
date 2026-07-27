import 'package:get/get.dart';

import 'sosmed_controller.dart';

class SosmedBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SosmedController>(() => SosmedController());
  }
}
