import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/filter_chips.dart';
import '../../data/models/activity.dart';
import 'riwayat_controller.dart';

class RiwayatView extends GetView<RiwayatController> {
  const RiwayatView({super.key});

  static const _typeOptions = [
    FilterOption('all', 'Semua'),
    FilterOption('attendance', 'Absensi'),
    FilterOption('leave', 'Cuti'),
    FilterOption('overtime', 'Lembur'),
    FilterOption('permission', 'Izin'),
    FilterOption('wfh', 'WFH'),
    FilterOption('reimbursement', 'Reimburse'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Riwayat Aktivitas',
      subtitle: 'Aktivitas terbaru',
      showBack: false,
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
              child: FilterChips(
                options: _typeOptions,
                selected: controller.typeFilter.value,
                onSelected: (v) => controller.typeFilter.value = v,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
              child: _dateBar(context),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.load,
                child: controller.visibleItems.isEmpty
                    ? _empty()
                    : _list(context),
              ),
            ),
          ],
        );
      }),
    );
  }

  /// Date-range filter chip: opens a range picker; shows the active range with
  /// a clear button.
  Widget _dateBar(BuildContext context) {
    return Obx(() {
      final active = controller.hasDateFilter;
      final label = active
          ? '${_fmtDate(controller.dateFrom.value!)} – ${_fmtDate(controller.dateTo.value!)}'
          : 'Filter Tanggal';
      return InkWell(
        onTap: () => _pickRange(context),
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryLight : AppColors.muted,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Icon(
                Iconsax.calendar_1,
                size: 16.sp,
                color: active ? AppColors.primary : AppColors.textMuted,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: active ? AppColors.primary : AppColors.textMuted,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (active)
                InkWell(
                  onTap: controller.clearDateRange,
                  borderRadius: BorderRadius.circular(100.r),
                  child: Padding(
                    padding: EdgeInsets.all(2.w),
                    child: Icon(
                      Iconsax.close_circle,
                      size: 17.sp,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final res = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: controller.hasDateFilter
          ? DateTimeRange(
              start: controller.dateFrom.value!,
              end: controller.dateTo.value!,
            )
          : null,
      helpText: 'Pilih rentang tanggal',
      saveText: 'Terapkan',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.navy,
          ),
        ),
        child: child!,
      ),
    );
    if (res != null) controller.setDateRange(res.start, res.end);
  }

  String _fmtDate(DateTime d) => formatTanggalLokal(d);

  Widget _empty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(height: 160.h),
        Icon(Iconsax.clock, size: 48.sp, color: AppColors.border),
        SizedBox(height: 12.h),
        Center(
          child: Text(
            'Belum ada aktivitas.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
          ),
        ),
      ],
    );
  }

  Widget _list(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        16.w,
        12.h,
        16.w,
        20.h + AppPage.bottomNavClearance(context),
      ),
      itemCount: controller.visibleItems.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (_, i) => _tile(controller.visibleItems[i]),
    );
  }

  Widget _tile(ActivityItem item) {
    final (icon, color) = _iconFor(item.type);

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, size: 20.sp, color: color),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  item.subtitle,
                  style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted),
                ),
                if (item.occurredAt != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    formatTanggalJam(item.occurredAt),
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (item.status != null && item.status!.isNotEmpty) ...[
            SizedBox(width: 8.w),
            _statusChip(item.status!),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  (IconData, Color) _iconFor(String type) {
    switch (type) {
      case 'attendance':
        return (Iconsax.finger_scan, AppColors.primary);
      case 'leave':
        return (Iconsax.sun_1, AppColors.success);
      case 'overtime':
        return (Iconsax.timer_1, AppColors.warning);
      case 'permission':
        return (Iconsax.calendar_remove, const Color(0xFF7C3AED));
      case 'wfh':
        return (Iconsax.house, const Color(0xFF0EA5E9));
      case 'reimbursement':
        return (Iconsax.wallet_money, const Color(0xFFDB2777));
      default:
        return (Iconsax.activity, AppColors.textMuted);
    }
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('approve') ||
        s.contains('setuju') ||
        s == 'present' ||
        s == 'hadir') {
      return AppColors.success;
    }
    if (s.contains('reject') ||
        s.contains('tolak') ||
        s == 'absent' ||
        s == 'alpha') {
      return AppColors.destructive;
    }
    if (s.contains('pending') ||
        s.contains('menunggu') ||
        s.contains('review')) {
      return AppColors.warning;
    }

    return AppColors.textMuted;
  }

  String _statusLabel(String status) {
    final s = status.toLowerCase();
    if (s.contains('approve') || s.contains('setuju')) {
      return 'Disetujui';
    }
    if (s.contains('reject') || s.contains('tolak')) {
      return 'Ditolak';
    }
    if (s.contains('pending') || s.contains('menunggu')) {
      return 'Menunggu';
    }

    return status[0].toUpperCase() + status.substring(1);
  }
}
