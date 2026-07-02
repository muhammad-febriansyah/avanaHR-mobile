import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/connectivity_service.dart';
import '../../routes/app_pages.dart';
import '../announcement/announcement_view.dart';
import '../home/views/home_tab.dart';
import '../profile/profile_view.dart';
import '../riwayat/riwayat_view.dart';
import 'main_controller.dart';

/// App shell: an IndexedStack of the four primary tabs behind a custom bottom
/// navigation bar. Keeps each tab's scroll/state alive when switching.
class MainView extends GetView<MainController> {
  const MainView({super.key});

  // Four side tabs; Absensi lives in the center floating action button.
  static const _tabs = <_NavItem>[
    _NavItem('Beranda', Iconsax.home_2),
    _NavItem('Riwayat', Iconsax.clock),
    _NavItem('Pengumuman', Iconsax.volume_high),
    _NavItem('Profil', Iconsax.user),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.muted,
      body: Column(
        children: [
          _offlineBanner(),
          Expanded(
            child: Obx(
              () => IndexedStack(
                index: controller.tab.value,
                children: const [
                  HomeTab(),
                  RiwayatView(),
                  AnnouncementView(),
                  ProfileView(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _absensiFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _bottomNav(),
    );
  }

  /// Prominent center button that opens the attendance (clock-in/out) screen.
  Widget _absensiFab() {
    return GestureDetector(
      onTap: () => Get.toNamed(Routes.ATTENDANCE),
      child: Container(
        width: 62.w,
        height: 62.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(Iconsax.finger_scan, color: Colors.white, size: 26.sp),
      ),
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
        color: const Color(0xFFDC2626),
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
                      style: TextStyle(fontSize: 11.5.sp, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _bottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(color: AppColors.navy.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          child: Obx(
            () => Row(
              children: [
                _navTab(0),
                _navTab(1),
                SizedBox(width: 64.w), // gap for the center Absensi FAB
                _navTab(2),
                _navTab(3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navTab(int i) {
    final item = _tabs[i];
    final active = controller.tab.value == i;

    return Expanded(
      child: InkWell(
        onTap: () => controller.changeTab(i),
        borderRadius: BorderRadius.circular(14.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(100.r),
                ),
                child: Icon(item.icon, size: 22.sp, color: active ? AppColors.primary : AppColors.textMuted),
              ),
              SizedBox(height: 4.h),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10.5.sp,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem(this.label, this.icon);
}
