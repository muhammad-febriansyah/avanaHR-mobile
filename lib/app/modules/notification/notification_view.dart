import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/ui.dart';
import 'notification_controller.dart';

class NotificationView extends GetView<NotificationController> {
  const NotificationView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Notifikasi',
      subtitle: 'Pemberitahuan',
      actions: [HeaderAction(Iconsax.tick_circle, controller.markAllRead)],
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Loading();
        }
        return RefreshIndicator(
          onRefresh: controller.load,
          color: AppColors.primary,
          child: controller.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    SizedBox(height: 80.h),
                    const EmptyState(
                      icon: Iconsax.notification,
                      message: 'Belum ada notifikasi.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
                  itemCount: controller.items.length,
                  separatorBuilder: (_, i) => SizedBox(height: 10.h),
                  itemBuilder: (_, i) {
                    final n = controller.items[i];
                    return ContentCard(
                      onTap: () => controller.markRead(n),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconBubble(Iconsax.notification, AppColors.primary),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.title,
                                  style: TextStyle(
                                    fontWeight: n.isRead
                                        ? FontWeight.w500
                                        : FontWeight.w700,
                                    color: AppColors.navy,
                                    fontSize: 13.5.sp,
                                  ),
                                ),
                                if (n.createdAt != null) ...[
                                  SizedBox(height: 2.h),
                                  Text(
                                    formatTanggalJam(n.createdAt),
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11.5.sp,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!n.isRead) ...[
                            SizedBox(width: 8.w),
                            Container(
                              width: 8.w,
                              height: 8.w,
                              margin: EdgeInsets.only(top: 4.h),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        );
      }),
    );
  }
}
