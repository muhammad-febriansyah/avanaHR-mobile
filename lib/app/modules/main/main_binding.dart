import 'package:get/get.dart';

import '../announcement/announcement_controller.dart';
import '../attendance/attendance_controller.dart';
import '../home/controllers/home_controller.dart';
import '../profile/profile_controller.dart';
import 'main_controller.dart';

/// Registers the shell controller plus every controller backing a bottom-nav
/// tab, since all tabs live in an IndexedStack and are built up-front.
class MainBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MainController>(() => MainController());
    Get.lazyPut<HomeController>(() => HomeController());
    Get.lazyPut<AttendanceController>(() => AttendanceController());
    Get.lazyPut<AnnouncementController>(() => AnnouncementController());
    Get.lazyPut<ProfileController>(() => ProfileController());
  }
}
