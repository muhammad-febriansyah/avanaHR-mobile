import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../announcement/announcement_view.dart';
import '../attendance/attendance_view.dart';
import '../home/views/home_tab.dart';
import '../profile/profile_view.dart';
import 'main_controller.dart';

/// App shell: an IndexedStack of the four primary tabs behind a custom bottom
/// navigation bar. Keeps each tab's scroll/state alive when switching.
class MainView extends GetView<MainController> {
  const MainView({super.key});

  static const _tabs = <_NavItem>[
    _NavItem('Beranda', Iconsax.home_2),
    _NavItem('Kehadiran', Iconsax.finger_scan),
    _NavItem('Pengumuman', Iconsax.volume_high),
    _NavItem('Profil', Iconsax.user),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.muted,
      body: Obx(
        () => IndexedStack(
          index: controller.tab.value,
          children: const [
            HomeTab(),
            AttendanceView(),
            AnnouncementView(),
            ProfileView(),
          ],
        ),
      ),
      bottomNavigationBar: _bottomNav(),
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
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (i) {
                final item = _tabs[i];
                final active = controller.tab.value == i;
                return Expanded(
                  child: InkWell(
                    onTap: () => controller.changeTab(i),
                    borderRadius: BorderRadius.circular(14.r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(vertical: 6.h),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 5.h),
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
              }),
            ),
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
