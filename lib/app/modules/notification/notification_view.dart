import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import 'notification_controller.dart';

class NotificationView extends GetView<NotificationController> {
  const NotificationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.muted,
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          Obx(
            () => controller.unread.value > 0
                ? TextButton(
                    onPressed: controller.markAllRead,
                    child: const Text('Tandai dibaca'),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.items.isEmpty) {
          return const Center(child: Text('Tidak ada notifikasi.'));
        }
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600),
            child: RefreshIndicator(
              onRefresh: controller.load,
              child: ListView.separated(
                padding: EdgeInsets.all(16.w),
                itemCount: controller.items.length,
                separatorBuilder: (_, i) => SizedBox(height: 10.h),
                itemBuilder: (_, i) {
                  final n = controller.items[i];
                  return Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: n.isRead ? AppColors.background : AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: n.isRead ? AppColors.border : AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(Iconsax.notification, color: AppColors.primary, size: 18.sp),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.title, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy, fontSize: 14.sp)),
                              if (n.createdAt != null)
                                Text(n.createdAt!, style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp)),
                            ],
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 8.w,
                            height: 8.w,
                            decoration: const BoxDecoration(color: AppColors.destructive, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }),
    );
  }
}
