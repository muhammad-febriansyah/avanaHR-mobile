import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/connectivity_service.dart';
import '../announcement/announcement_view.dart';
import '../attendance/attendance_view.dart';
import '../home/views/home_tab.dart';
import '../profile/profile_view.dart';
import '../riwayat/riwayat_view.dart';
import 'main_controller.dart';

/// App shell: five persistent tabs behind a `persistent_bottom_nav_bar_v2`
/// Style 8 nav bar (the selected item expands into a pill). Absensi sits in the
/// center. Each tab keeps its scroll/state alive when switching.
class MainView extends GetView<MainController> {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.muted,
      body: Column(
        children: [
          _offlineBanner(),
          Expanded(child: _tabView()),
        ],
      ),
    );
  }

  Widget _tabView() {
    return PersistentTabView(
      controller: controller.pageController,
      // Transparent + full overlap: tab content extends behind the nav bar so
      // Style 13's floating-button gutter shows the page (seamless) instead of
      // a white strip. Scroll views reserve bottom space for the bar height.
      backgroundColor: Colors.transparent,
      navBarOverlap: const NavBarOverlap.full(),
      handleAndroidBackButtonPress: true,
      stateManagement: true,
      tabs: [
        PersistentTabConfig(
          screen: const HomeTab(),
          item: _item(Iconsax.home_2, 'Beranda'),
        ),
        PersistentTabConfig(
          screen: const RiwayatView(),
          item: _item(Iconsax.clock, 'Riwayat'),
        ),
        // Center item (index 2) — rendered as the floating circle by Style 13.
        PersistentTabConfig(
          screen: _absensiScreen(),
          item: _middleItem(Iconsax.finger_scan),
        ),
        PersistentTabConfig(
          screen: const AnnouncementView(),
          item: _item(Iconsax.volume_high, 'Pengumuman'),
        ),
        PersistentTabConfig(
          screen: const ProfileView(),
          item: _item(Iconsax.user, 'Profil'),
        ),
      ],
      navBarBuilder: (navBarConfig) => Style13BottomNavBar(
        navBarConfig: navBarConfig,
        height: 64.h,
        middleItemSize: 58.w,
        navBarDecoration: NavBarDecoration(
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
        ),
      ),
    );
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
