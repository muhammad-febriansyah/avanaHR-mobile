import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../data/models/activity.dart';
import 'riwayat_controller.dart';

class RiwayatView extends GetView<RiwayatController> {
  const RiwayatView({super.key});

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

        return RefreshIndicator(
          onRefresh: controller.load,
          child: controller.items.isEmpty ? _empty() : _list(),
        );
      }),
    );
  }

  Widget _empty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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

  Widget _list() {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
      itemCount: controller.items.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (_, i) => _tile(controller.items[i]),
    );
  }

  Widget _tile(ActivityItem item) {
    final (icon, color) = _iconFor(item.type);

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
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
                    DateFormat(
                      'd MMM yyyy · HH:mm',
                    ).format(item.occurredAt!.toLocal()),
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
