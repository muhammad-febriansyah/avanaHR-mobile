import 'package:get/get.dart';

import '../../data/models/mss.dart';
import 'mss_member_controller.dart';

class MssMemberBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MssMemberController>(() => MssMemberController(Get.arguments as MssTeamMember));
  }
}
