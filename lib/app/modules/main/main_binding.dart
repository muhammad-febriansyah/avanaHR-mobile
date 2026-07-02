import 'package:get/get.dart';

import '../announcement/announcement_controller.dart';
import '../home/controllers/home_controller.dart';
import '../profile/profile_controller.dart';
import '../riwayat/riwayat_controller.dart';
import 'main_controller.dart';

/// Registers the shell controller plus every controller backing a bottom-nav
/// tab, since all tabs live in an IndexedStack and are built up-front.
/// Absensi is a pushed route (its own binding), not a tab.
class MainBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MainController>(() => MainController());
    Get.lazyPut<HomeController>(() => HomeController());
    Get.lazyPut<RiwayatController>(() => RiwayatController());
    Get.lazyPut<AnnouncementController>(() => AnnouncementController());
    Get.lazyPut<ProfileController>(() => ProfileController());
  }
}
