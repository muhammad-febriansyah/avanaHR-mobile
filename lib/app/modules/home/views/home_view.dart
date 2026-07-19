import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../../../routes/app_pages.dart';
import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.muted,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refreshAll,
          color: AppColors.primary,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
                children: [
                  _header(),
                  SizedBox(height: 18.h),
                  _attendanceCard(),
                  SizedBox(height: 22.h),
                  SectionTitle('Menu Cepat'),
                  SizedBox(height: 14.h),
                  _actionsGrid(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _initials {
    final parts = controller.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((e) => e[0].toUpperCase()).join();
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 46.w,
          height: 46.w,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14.r),
          ),
          alignment: Alignment.center,
          child: Obx(
            () => Text(
              controller.name.isEmpty ? '' : _initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16.sp,
              ),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selamat datang,',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5.sp),
              ),
              Obx(
                () => Text(
                  controller.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        Obx(
          () => _iconButton(
            Iconsax.notification,
            () => Get.toNamed(Routes.NOTIFICATION),
            badge: controller.unread.value,
          ),
        ),
        SizedBox(width: 8.w),
        _iconButton(Iconsax.logout, controller.logout),
      ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap, {int badge = 0}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Stack(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: softCard(radius: 12),
            child: Icon(icon, color: AppColors.navy, size: 21.sp),
          ),
          if (badge > 0)
            Positioned(
              right: 4.w,
              top: 4.h,
              child: Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: AppColors.destructive,
                  shape: BoxShape.circle,
                ),
                constraints: BoxConstraints(minWidth: 16.w, minHeight: 16.w),
                child: Text(
                  '$badge',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _attendanceCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Obx(() {
        final t = controller.today.value;
        final clockIn = t?.clockIn ?? '--:--';
        final clockOut = t?.clockOut ?? '--:--';
        final next = t?.canClockIn ?? true;
        final status = t?.status;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Absensi Hari Ini',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (status != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                _clockStat(Iconsax.login, 'Masuk', clockIn),
                Container(
                  width: 1,
                  height: 34.h,
                  color: Colors.white.withValues(alpha: 0.25),
                  margin: EdgeInsets.symmetric(horizontal: 18.w),
                ),
                _clockStat(Iconsax.logout, 'Pulang', clockOut),
              ],
            ),
            SizedBox(height: 18.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  minimumSize: Size.fromHeight(48.h),
                  elevation: 0,
                ),
                onPressed: () => Get.toNamed(Routes.ATTENDANCE),
                icon: Icon(
                  next ? Iconsax.finger_scan : Iconsax.logout,
                  size: 20.sp,
                ),
                label: Text(next ? 'Clock In Sekarang' : 'Clock Out'),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _clockStat(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 20.sp),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11.sp,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 19.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionsGrid() {
    final items = [
      _Action(
        'Absensi',
        Iconsax.finger_scan,
        Routes.ATTENDANCE,
        const Color(0xFF2547F9),
      ),
      _Action('Cuti', Iconsax.sun_1, Routes.LEAVE, const Color(0xFF22C55E)),
      _Action(
        'Lembur',
        Iconsax.timer_1,
        Routes.OVERTIME,
        const Color(0xFFF59E0B),
      ),
      _Action(
        'Izin',
        Iconsax.calendar_remove,
        Routes.PERMISSION,
        const Color(0xFF7C3AED),
      ),
      _Action('WFH', Iconsax.house, Routes.WFH, const Color(0xFF0EA5E9)),
      _Action(
        'Reimburse',
        Iconsax.wallet_money,
        Routes.REIMBURSEMENT,
        const Color(0xFFDB2777),
      ),
      _Action(
        'Settlement',
        Iconsax.receipt_2_1,
        Routes.SETTLEMENT,
        const Color(0xFF2563EB),
      ),
      _Action(
        'Uang Muka',
        Iconsax.wallet_add,
        Routes.KASBON,
        const Color(0xFF7C3AED),
      ),
      _Action(
        'Slip Gaji',
        Iconsax.receipt_2,
        Routes.PAYSLIP,
        const Color(0xFF0891B2),
      ),
      _Action(
        'Tukar Shift',
        Iconsax.arrow_swap_horizontal,
        Routes.SHIFT_SWAP,
        const Color(0xFF0D9488),
      ),
      _Action(
        'Dokumen',
        Iconsax.document_text,
        Routes.DOKUMEN,
        const Color(0xFF9333EA),
      ),
      _Action(
        'Visiting',
        Iconsax.location,
        Routes.VISITING,
        const Color(0xFFE11D48),
      ),
      _Action(
        'Pengumuman',
        Iconsax.volume_high,
        Routes.ANNOUNCEMENT,
        const Color(0xFFEA580C),
      ),
      _Action(
        'Daftar Wajah',
        Iconsax.scan,
        Routes.FACE_ENROLL,
        const Color(0xFF4F46E5),
      ),
      _Action('Profil', Iconsax.user, Routes.PROFILE, const Color(0xFF475569)),
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14.h,
      crossAxisSpacing: 12.w,
      childAspectRatio: 0.82,
      children: items
          .map(
            (a) => InkWell(
              borderRadius: BorderRadius.circular(16.r),
              onTap: () => Get.toNamed(a.route),
              child: Column(
                children: [
                  Container(
                    width: 54.w,
                    height: 54.w,
                    decoration: BoxDecoration(
                      color: a.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Icon(a.icon, color: a.color, size: 25.sp),
                  ),
                  SizedBox(height: 7.h),
                  Text(
                    a.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                      fontSize: 11.sp,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Action {
  final String label;
  final IconData icon;
  final String route;
  final Color color;
  _Action(this.label, this.icon, this.route, this.color);
}
