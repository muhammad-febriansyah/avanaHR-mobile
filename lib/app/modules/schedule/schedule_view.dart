import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/schedule.dart';
import 'schedule_controller.dart';

class ScheduleView extends GetView<ScheduleController> {
  const ScheduleView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Jadwal Shift',
      subtitle: 'Shift kamu minggu ini',
      child: Column(
        children: [
          _weekBar(),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Loading();
              }
              if (controller.days.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: 80.h),
                    const EmptyState(
                      icon: Iconsax.calendar_1,
                      message: 'Jadwal belum tersedia.',
                    ),
                  ],
                );
              }
              return RefreshIndicator(
                onRefresh: controller.load,
                color: AppColors.primary,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
                  itemCount: controller.days.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10.h),
                  itemBuilder: (_, i) => _dayCard(controller.days[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _weekBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
      child: Row(
        children: [
          _navBtn(Iconsax.arrow_left_2, () => controller.shiftWeek(-1)),
          Expanded(
            child: Obx(() {
              final days = controller.days;
              final label = days.isEmpty
                  ? 'Minggu ini'
                  : '${_short(days.first.date)} – ${_short(days.last.date)}';
              return GestureDetector(
                onTap: controller.resetToThisWeek,
                child: Column(
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy)),
                    Text('Ketuk untuk minggu ini',
                        style: TextStyle(fontSize: 10.sp, color: AppColors.textMuted)),
                  ],
                ),
              );
            }),
          ),
          _navBtn(Iconsax.arrow_right_3, () => controller.shiftWeek(1)),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        width: 38.w,
        height: 38.w,
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(icon, size: 18.sp, color: AppColors.navy),
      ),
    );
  }

  Widget _dayCard(ShiftDay d) {
    final Color accent;
    final String status;
    final IconData icon;

    if (!d.isScheduled) {
      accent = AppColors.textMuted;
      status = 'Belum dijadwalkan';
      icon = Iconsax.calendar_remove;
    } else if (d.isOff) {
      accent = const Color(0xFF0EA5E9);
      status = 'Libur';
      icon = Iconsax.coffee;
    } else {
      accent = AppColors.primary;
      status = '${d.start ?? '--'} – ${d.end ?? '--'}';
      icon = Iconsax.clock;
    }

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: d.isToday ? AppColors.primary.withValues(alpha: 0.06) : AppColors.background,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: d.isToday ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
          width: d.isToday ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 52.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: d.isToday ? AppColors.primary : AppColors.muted,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(d.dayShort,
                    style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: d.isToday ? Colors.white70 : AppColors.textMuted)),
                Text(_dayNum(d.date),
                    style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        color: d.isToday ? Colors.white : AppColors.navy)),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(d.dayLabel,
                        style: TextStyle(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy)),
                    if (d.isToday) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('Hari ini',
                            style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 3.h),
                Text(d.isScheduled && !d.isOff ? (d.shiftName ?? 'Shift') : status,
                    style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: accent)),
              ],
            ),
          ),
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, size: 17.sp, color: accent),
          ),
        ],
      ),
    );
  }

  String _dayNum(String date) {
    final parts = date.split('-');
    return parts.length == 3 ? parts[2] : '--';
  }

  String _short(String date) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final parts = date.split('-');
    if (parts.length != 3) {
      return date;
    }
    final m = int.tryParse(parts[1]) ?? 0;
    return '${int.tryParse(parts[2]) ?? parts[2]} ${m >= 1 && m <= 12 ? months[m] : ''}'.trim();
  }
}
