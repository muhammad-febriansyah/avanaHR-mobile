import 'package:get/get.dart';

import 'dokumen_controller.dart';

class DokumenBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DokumenController>(() => DokumenController());
  }
}
