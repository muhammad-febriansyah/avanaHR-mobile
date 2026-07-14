import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../data/models/mss.dart';
import '../../routes/app_pages.dart';
import 'dashboard_controller.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Dashboard',
      subtitle: 'Ringkasan tim Anda',
      actions: [HeaderAction(Iconsax.refresh, controller.load)],
      onRefresh: controller.load,
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
          children: [
            _kpiGrid(),
            SizedBox(height: 20.h),
            _todayCard(),
            SizedBox(height: 16.h),
            _pendingCard(),
            SizedBox(height: 16.h),
            _monthCard(),
          ],
        );
      }),
    );
  }

  // ---- KPI grid -------------------------------------------------------------

  Widget _kpiGrid() {
    final t = controller.today.value;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _kpi(
                Iconsax.people,
                AppColors.primary,
                'Anggota Tim',
                '${controller.teamCount.value}',
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _kpi(
                Iconsax.task_square,
                AppColors.warning,
                'Menunggu Persetujuan',
                '${controller.pendingCount.value}',
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _kpi(
                Iconsax.tick_circle,
                AppColors.success,
                'Hadir Hari Ini',
                '${t?.present ?? 0}',
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _kpi(
                Iconsax.clock,
                AppColors.destructive,
                'Terlambat Hari Ini',
                '${t?.late ?? 0}',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _kpi(IconData icon, Color color, String label, String value) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11.r),
            ),
            child: Icon(icon, color: color, size: 19.sp),
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ---- Today's attendance breakdown ----------------------------------------

  Widget _todayCard() {
    final t = controller.today.value;
    return _card(
      title: 'Absensi Tim Hari Ini',
      child: t == null
          ? _emptyLine('Belum ada data absensi hari ini.')
          : Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _tally('Hadir', t.present, AppColors.success),
                _tally('Terlambat', t.late, AppColors.warning),
                _tally('Alpa', t.absent, AppColors.destructive),
                _tally('Cuti', t.leave, const Color(0xFF9333EA)),
                _tally('WFH', t.wfh, const Color(0xFF0EA5E9)),
              ],
            ),
    );
  }

  Widget _tally(String label, int value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Pending approvals preview -------------------------------------------

  Widget _pendingCard() {
    final items = controller.pendingPreview;
    return _card(
      title: 'Persetujuan Menunggu',
      onSeeAll: () => Get.toNamed(Routes.MSS),
      child: items.isEmpty
          ? _emptyLine('Tidak ada permintaan menunggu.')
          : Column(
              children: [
                for (final a in items) ...[
                  _pendingRow(a),
                  if (a != items.last) SizedBox(height: 10.h),
                ],
              ],
            ),
    );
  }

  Widget _pendingRow(MssApproval a) {
    return Row(
      children: [
        Container(
          width: 38.w,
          height: 38.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: a.avatarColor,
          ),
          child: Text(
            a.initials,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13.sp,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a.employeeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                a.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5.sp, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            a.typeLabel,
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ---- Month recap ----------------------------------------------------------

  Widget _monthCard() {
    final m = controller.month.value;
    return _card(
      title: 'Rekap Tim Bulan Ini',
      onSeeAll: () => Get.toNamed(Routes.MSS_RECAP),
      child: m == null
          ? _emptyLine('Belum ada rekap bulan ini.')
          : Row(
              children: [
                _metric('Hadir', '${m.present}', AppColors.success),
                _metric('Terlambat', '${m.late}', AppColors.warning),
                _metric(
                  'Jam Kerja',
                  m.workHours.toStringAsFixed(0),
                  AppColors.primary,
                ),
              ],
            ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ---- Shared ---------------------------------------------------------------

  Widget _card({
    required String title,
    required Widget child,
    VoidCallback? onSeeAll,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              if (onSeeAll != null)
                GestureDetector(
                  onTap: onSeeAll,
                  child: Text(
                    'Lihat Semua',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 14.h),
          child,
        ],
      ),
    );
  }

  Widget _emptyLine(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted),
    );
  }
}
