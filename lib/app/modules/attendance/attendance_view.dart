import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../data/services/attendance_queue_service.dart';
import 'attendance_controller.dart';

class AttendanceView extends GetView<AttendanceController> {
  const AttendanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Absensi',
      subtitle: 'Clock in / clock out',
      child: Column(
        children: [
          _pendingBanner(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  /// A slim amber bar shown while queued clock actions await sync.
  Widget _pendingBanner() {
    final queue = Get.find<AttendanceQueueService>();
    return Obx(() {
      if (queue.pendingCount.value == 0) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        color: const Color(0xFFFEF3C7),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Row(
          children: [
            Icon(Iconsax.clock, size: 15.sp, color: const Color(0xFFB45309)),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                '${queue.pendingCount.value} absen menunggu sinkron — terkirim otomatis saat online',
                style: TextStyle(
                  fontSize: 11.5.sp,
                  color: const Color(0xFFB45309),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _body() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final t = controller.today.value;
      final isIn = t?.canClockIn ?? true;
      return RefreshIndicator(
        onRefresh: controller.load,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(20.w),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(18.r),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  t?.date ?? '-',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13.sp,
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _stat('Masuk', t?.clockIn ?? '--:--'),
                                    Container(
                                      width: 1,
                                      height: 40.h,
                                      color: AppColors.border,
                                    ),
                                    _stat('Pulang', t?.clockOut ?? '--:--'),
                                  ],
                                ),
                                if (t?.status != null) ...[
                                  SizedBox(height: 12.h),
                                  Text(
                                    'Status: ${t!.status}',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13.sp,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: controller.isClocking.value
                                ? null
                                : controller.clock,
                            child: Container(
                              height: 180.w,
                              width: 180.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: isIn
                                      ? [AppColors.primary, AppColors.accent]
                                      : [
                                          AppColors.warning,
                                          const Color(0xFFF59E0B),
                                        ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (isIn
                                                ? AppColors.primary
                                                : AppColors.warning)
                                            .withValues(alpha: 0.4),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: controller.isClocking.value
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isIn
                                                ? Iconsax.login
                                                : Iconsax.logout,
                                            color: Colors.white,
                                            size: 48.sp,
                                          ),
                                          SizedBox(height: 8.h),
                                          Text(
                                            isIn ? 'CLOCK IN' : 'CLOCK OUT',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16.sp,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'Pastikan GPS aktif. Lokasi direkam saat absen.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12.sp,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }
}
