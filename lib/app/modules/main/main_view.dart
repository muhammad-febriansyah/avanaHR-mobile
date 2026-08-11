import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ai_fab.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/connectivity_service.dart';
import '../announcement/announcement_view.dart';
import '../attendance/attendance_view.dart';
import '../home/views/home_tab.dart';
import '../profile/profile_view.dart';
import '../sosmed/sosmed_view.dart';
import 'account_unlinked_view.dart';
import 'main_controller.dart';

/// App shell: the persistent tabs the server allows this account, behind a
/// `persistent_bottom_nav_bar_v2` bar. Absensi gets the Style 13 floating
/// centre circle when it happens to sit in the middle of an odd-length bar,
/// and the bar falls back to Style 2 (the selected item expands into a rounded
/// pill) otherwise. Each tab keeps its scroll/state alive when switching.
class MainView extends GetView<MainController> {
  const MainView({super.key});

  /// Nav bar height the floating AI button has to clear.
  static const double _navBarHeight = 64;

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();

    return Obx(() {
      // An account with no employee behind it can use none of these tabs —
      // every API call would come back 403. Stop it here with instructions
      // instead of letting it land on a dashboard of empty counters and a
      // dismissible error toast. Reactive: the moment a re-check (or pull to
      // refresh) comes back with the employee linked, the shell takes over.
      final user = auth.user.value;
      if (user != null && user.employee == null) {
        return const AccountUnlinkedView();
      }

      return _shell();
    });
  }

  Widget _shell() {
    final keys = controller.tabKeys;
    final centred = MainController.absensiIsCentred(keys);

    return Scaffold(
      backgroundColor: AppColors.muted,
      body: Column(
        children: [
          _offlineBanner(),
          Expanded(
            // The AI shortcut is stacked over the tabs, not handed to
            // Scaffold.floatingActionButton: this Scaffold owns no
            // bottomNavigationBar (the persistent bar draws itself), so a
            // Scaffold FAB would sit under the bar instead of above it.
            child: Stack(
              children: [
                _tabView(keys, centred: centred),
                Positioned(
                  right: 16.w,
                  bottom: _navBarHeight.h + (centred ? 28.h : 70.h),
                  // Hidden on Absensi: that tab is a full-bleed camera/GPS flow
                  // where a floating button would sit over the face frame.
                  child: Obx(
                    () => controller.tab.value == controller.attendanceTab
                        ? const SizedBox.shrink()
                        : const AiFab(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabView(List<String> keys, {required bool centred}) {
    // Style 13 draws whichever item sits at the middle *position* as the
    // floating circle, and asserts the count is odd. Neither holds once the
    // bar comes from the server: a company that switches one tab off leaves
    // an even count (assertion crash), and one that reorders them puts the
    // circle on a tab that never asked to be a circle.
    return PersistentTabView(
      controller: controller.pageController,
      // Transparent + full overlap: tab content extends behind the nav bar so
      // Style 13's floating-button gutter shows the page (seamless) instead of
      // a white strip. Scroll views reserve bottom space for the bar height.
      backgroundColor: Colors.transparent,
      navBarOverlap: const NavBarOverlap.full(),
      handleAndroidBackButtonPress: true,
      stateManagement: true,
      tabs: _tabs(keys, centred: centred),
      navBarBuilder: (navBarConfig) => centred
          ? Style13BottomNavBar(
              navBarConfig: navBarConfig,
              height: 64.h,
              middleItemSize: 58.w,
              navBarDecoration: _barDecoration(),
            )
          : Style2BottomNavBar(
              navBarConfig: navBarConfig,
              height: 64.h,
              navBarDecoration: _barDecoration(),
            ),
    );
  }

  NavBarDecoration _barDecoration() {
    return NavBarDecoration(
      color: AppColors.surface,
      // A soft upward shadow so the bar reads as floating over the page —
      // a hard top border draws a full-width line that looks like the
      // content is cut off above the bar.
      boxShadow: [
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, -6),
        ),
      ],
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
    );
  }

  /// The bar, built from the keys the server sent for this account. A key this
  /// build does not know is skipped rather than crashing a whole bar over one
  /// new tab. Absensi is drawn as the floating circle only when [centred];
  /// anywhere else it needs a label and normal colours like its neighbours,
  /// since no style would render it as a circle there.
  List<PersistentTabConfig> _tabs(List<String> keys, {required bool centred}) {
    final labels = {
      for (final tab in Get.find<AuthService>().user.value?.tabs ?? [])
        tab.key: tab.label,
    };

    return keys
        .map((key) => _tabFor(key, labels[key], centred: centred))
        .whereType<PersistentTabConfig>()
        .toList();
  }

  /// One tab, or null when this build has no screen for that key.
  PersistentTabConfig? _tabFor(
    String key,
    String? label, {
    required bool centred,
  }) {
    switch (key) {
      case 'beranda':
        return PersistentTabConfig(
          screen: const HomeTab(),
          item: _item(Iconsax.home_2, label ?? 'Beranda'),
        );
      // Sosmed replaced Riwayat here; Riwayat moved into Menu Cepat, since
      // the wall is opened many times a day and history only occasionally.
      case 'sosmed':
        return PersistentTabConfig(
          screen: const SosmedView(),
          item: _item(Iconsax.people, label ?? 'Ruang Kita'),
        );
      case 'absensi':
        return PersistentTabConfig(
          screen: _absensiScreen(),
          item: centred
              ? _middleItem(Iconsax.finger_scan)
              : _item(Iconsax.finger_scan, label ?? 'Absensi'),
        );
      case 'pengumuman':
        return PersistentTabConfig(
          screen: const AnnouncementView(),
          item: _item(Iconsax.volume_high, label ?? 'Pengumuman'),
        );
      case 'profil':
        return PersistentTabConfig(
          screen: const ProfileView(),
          item: _item(Iconsax.user, label ?? 'Profil'),
        );
      default:
        return null;
    }
  }

  ItemConfig _item(IconData icon, String title) {
    return ItemConfig(
      icon: Icon(icon),
      title: title,
      iconSize: 22.sp,
      activeForegroundColor: AppColors.primary,
      inactiveForegroundColor: AppColors.textMuted,
      textStyle: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700),
    );
  }

  /// Center floating item: a blue circle (`activeForegroundColor`) with a white
  /// icon (`inactiveForegroundColor`). No label — the circle is self-evident.
  ItemConfig _middleItem(IconData icon) {
    return ItemConfig(
      icon: Icon(icon),
      iconSize: 26.sp,
      activeForegroundColor: AppColors.primary, // circle fill
      inactiveForegroundColor: Colors.white, // icon inside circle
    );
  }

  /// Absensi is built only once first opened, so its GPS/camera init doesn't
  /// fire at app launch. Until then the tab shows nothing.
  Widget _absensiScreen() {
    return Obx(
      () => controller.attendanceOpened.value
          ? const AttendanceView()
          : const SizedBox.shrink(),
    );
  }

  /// A slim red bar shown whenever the device loses its network connection.
  Widget _offlineBanner() {
    final connectivity = Get.find<ConnectivityService>();
    return Obx(
      () => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: connectivity.online.value ? 0 : 30.h,
        width: double.infinity,
        color: AppColors.destructive,
        alignment: Alignment.center,
        child: connectivity.online.value
            ? const SizedBox.shrink()
            : SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Iconsax.wifi_square, size: 14.sp, color: Colors.white),
                    SizedBox(width: 6.w),
                    Text(
                      'Tidak ada koneksi internet',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
