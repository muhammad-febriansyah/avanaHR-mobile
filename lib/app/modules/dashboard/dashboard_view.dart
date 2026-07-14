import 'dart:math' as math;

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
    final segments = t == null
        ? <_Seg>[]
        : <_Seg>[
            _Seg('Hadir', t.present, AppColors.success),
            _Seg('Terlambat', t.late, AppColors.warning),
            _Seg('Alpa', t.absent, AppColors.destructive),
            _Seg('Cuti', t.leave, const Color(0xFF9333EA)),
            _Seg('WFH', t.wfh, const Color(0xFF0EA5E9)),
          ];
    final total = segments.fold<int>(0, (s, e) => s + e.value);

    return _card(
      title: 'Absensi Tim Hari Ini',
      child: total == 0
          ? _emptyLine('Belum ada data absensi hari ini.')
          : Row(
              children: [
                _DonutChart(segments: segments, total: total),
                SizedBox(width: 18.w),
                Expanded(
                  child: Column(
                    children: [for (final s in segments) _legendRow(s)],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _legendRow(_Seg s) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3.h),
      child: Row(
        children: [
          Container(
            width: 9.w,
            height: 9.w,
            decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              s.label,
              style: TextStyle(fontSize: 12.sp, color: AppColors.textPrimary),
            ),
          ),
          Text(
            '${s.value}',
            style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
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

/// One slice of the attendance donut.
class _Seg {
  final String label;
  final int value;
  final Color color;
  const _Seg(this.label, this.value, this.color);
}

/// A flat donut chart with a total in the centre, drawn without any package.
class _DonutChart extends StatelessWidget {
  final List<_Seg> segments;
  final int total;

  const _DonutChart({required this.segments, required this.total});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96.w,
      height: 96.w,
      child: CustomPaint(
        painter: _DonutPainter(segments, total),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$total',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              Text(
                'total',
                style: TextStyle(fontSize: 10.sp, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_Seg> segments;
  final int total;

  _DonutPainter(this.segments, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) {
      return;
    }
    final stroke = size.width * 0.16;
    final rect =
        Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    var start = -math.pi / 2;
    const gap = 0.05; // radians of spacing between slices

    for (final s in segments) {
      if (s.value <= 0) {
        continue;
      }
      final sweep = (s.value / total) * (2 * math.pi);
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(sweep - gap, 0.001),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.total != total || old.segments != segments;
}
