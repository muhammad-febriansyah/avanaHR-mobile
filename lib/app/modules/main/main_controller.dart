import 'package:get/get.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

import '../../core/widgets/connection_dialog.dart';
import '../../data/services/connectivity_service.dart';

/// Holds the active bottom-navigation tab for the app shell.
///
/// Five tabs: Beranda(0), Riwayat(1), Absensi(2, center), Pengumuman(3),
/// Profil(4). Absensi is built lazily (only after first opened) so its
/// controller doesn't request GPS/camera at app launch.
class MainController extends GetxController {
  static const attendanceTab = 2;

  /// Drives the [PersistentTabView]. Tapping a nav item and [changeTab] both
  /// funnel through this controller.
  final PersistentTabController pageController = PersistentTabController(
    initialIndex: 0,
  );

  /// Mirror of [pageController.index] as an observable, for widgets that react
  /// to the active tab (e.g. the face-scan camera worker).
  final tab = 0.obs;
  final attendanceOpened = false.obs;

  final ConnectivityService _conn = Get.find();
  Worker? _connWorker;
  bool _connDialogOpen = false;

  @override
  void onInit() {
    super.onInit();
    pageController.addListener(_sync);
    // Pop a warning whenever the internet becomes unreachable; auto-dismiss it
    // once the connection is restored.
    _connWorker = ever<ConnStatus>(_conn.status, _onConnChange);
  }

  void _onConnChange(ConnStatus s) {
    if (s == ConnStatus.online) {
      if (_connDialogOpen && (Get.isDialogOpen ?? false)) {
        Get.back();
      }
      _connDialogOpen = false;
      return;
    }
    if (_connDialogOpen) return;
    _connDialogOpen = true;
    Get.dialog(
      ConnectionDialog(offline: s == ConnStatus.offline),
      barrierDismissible: true,
    ).then((_) => _connDialogOpen = false);
  }

  void _sync() {
    tab.value = pageController.index;
    if (pageController.index == attendanceTab) {
      attendanceOpened.value = true;
    }
  }

  /// Programmatic tab switch (from quick actions / home shortcuts).
  void changeTab(int index) => pageController.jumpToTab(index);

  @override
  void onClose() {
    _connWorker?.dispose();
    pageController.removeListener(_sync);
    pageController.dispose();
    super.onClose();
  }
}
