import 'package:get/get.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

import '../../core/widgets/connection_dialog.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/connectivity_service.dart';

/// Holds the active bottom-navigation tab for the app shell.
///
/// The bar itself comes from the server (`tabs` on the login payload), already
/// filtered by the company's features and the account's role, so switching
/// Ruang Kita off in Hak Akses removes the tab without a new build. Which tab
/// sits at which index therefore varies, and nothing may assume a fixed one.
///
/// Absensi is built lazily (only after first opened) so its controller doesn't
/// request GPS/camera at app launch.
class MainController extends GetxController {
  /// The bar this build ships with, used when the server sends none — an older
  /// backend, or a session stored before the field existed.
  static const fallbackTabKeys = [
    'beranda',
    'sosmed',
    'absensi',
    'pengumuman',
    'profil',
  ];

  final AuthService _auth = Get.find();

  /// Tab keys in bar order, as this account sees them.
  List<String> get tabKeys {
    final tabs = _auth.user.value?.tabs ?? const [];

    return tabs.isEmpty
        ? fallbackTabKeys
        : tabs.map((tab) => tab.key).toList(growable: false);
  }

  /// Where Absensi sits, or -1 when the company switched it off.
  int get attendanceTab => tabKeys.indexOf('absensi');

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
    if (attendanceTab >= 0 && pageController.index == attendanceTab) {
      attendanceOpened.value = true;
    }
  }

  /// Programmatic tab switch (from quick actions / home shortcuts).
  void changeTab(int index) => pageController.jumpToTab(index);

  /// Switch by key rather than position: a hidden tab shifts every index after
  /// it, so `changeTab(3)` would land somewhere else entirely. Does nothing
  /// when the company does not show that tab.
  void changeTabByKey(String key) {
    final index = tabKeys.indexOf(key);

    if (index >= 0) {
      pageController.jumpToTab(index);
    }
  }

  @override
  void onClose() {
    _connWorker?.dispose();
    pageController.removeListener(_sync);
    pageController.dispose();
    super.onClose();
  }
}
