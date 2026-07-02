import 'package:get/get.dart';

import 'visiting_controller.dart';

class VisitingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VisitingController>(() => VisitingController());
  }
}
