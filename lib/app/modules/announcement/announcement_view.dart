import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/ui.dart';
import 'announcement_controller.dart';

class AnnouncementView extends GetView<AnnouncementController> {
  const AnnouncementView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Pengumuman',
      subtitle: 'Info terbaru',
      showBack: false,
      reserveBottomNav: true,
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Loading();
        }
        return RefreshIndicator(
          onRefresh: controller.load,
          color: AppColors.primary,
          child: controller.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  children: [
                    SizedBox(height: 80.h),
                    const EmptyState(
                      icon: Iconsax.volume_high,
                      message: 'Belum ada pengumuman.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
                  itemCount: controller.items.length,
                  separatorBuilder: (_, i) => SizedBox(height: 10.h),
                  itemBuilder: (_, i) {
                    final a = controller.items[i];
                    return ContentCard(
                      child: Row(
                        children: [
                          IconBubble(
                            a.pinned ? Iconsax.paperclip2 : Iconsax.volume_high,
                            const Color(0xFFEA580C),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                    fontSize: 13.5.sp,
                                  ),
                                ),
                                if (a.body != null && a.body!.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(top: 2.h),
                                    child: Text(
                                      a.body!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (a.publishedAt != null) ...[
                            SizedBox(width: 8.w),
                            Text(
                              a.publishedAt!.split('T').first,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10.5.sp,
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
