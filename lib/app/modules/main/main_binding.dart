import 'package:get/get.dart';

import '../announcement/announcement_controller.dart';
import '../attendance/attendance_controller.dart';
import '../home/controllers/home_controller.dart';
import '../profile/profile_controller.dart';
import '../sosmed/sosmed_controller.dart';
import 'main_controller.dart';

/// Registers the shell controller plus every controller backing a bottom-nav
/// tab, since all tabs live in an IndexedStack and are built up-front.
class MainBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MainController>(() => MainController());
    Get.lazyPut<HomeController>(() => HomeController());
    // Sosmed is a bottom-nav tab, so its controller must be registered here:
    // tabs are constructed directly by the shell and never go through
    // SosmedBinding, which only runs for the pushed /sosmed route.
    Get.lazyPut<SosmedController>(() => SosmedController());
    Get.lazyPut<AnnouncementController>(() => AnnouncementController());
    Get.lazyPut<ProfileController>(() => ProfileController());
    // Absensi is the center-FAB tab. fenix keeps it revivable if the standalone
    // ATTENDANCE route is ever pushed+popped and disposes the shared instance.
    Get.lazyPut<AttendanceController>(() => AttendanceController(), fenix: true);
  }
}
