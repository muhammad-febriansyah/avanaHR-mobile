import 'package:get/get.dart';

/// Holds the active bottom-navigation tab for the app shell.
///
/// Tabs 0–3 are the side navigation; tab 4 is the Absensi screen behind the
/// center FAB. Absensi is built lazily (only after it's first opened) so its
/// controller doesn't request GPS at app launch.
class MainController extends GetxController {
  static const attendanceTab = 4;

  final tab = 0.obs;
  final attendanceOpened = false.obs;

  void changeTab(int index) {
    if (index == attendanceTab) {
      attendanceOpened.value = true;
    }
    tab.value = index;
  }
}
