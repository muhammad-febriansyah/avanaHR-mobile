import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui.dart';
import 'announcement_controller.dart';

class AnnouncementView extends GetView<AnnouncementController> {
  const AnnouncementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.muted,
      appBar: AppBar(title: const Text('Pengumuman')),
      body: Obx(() {
        if (controller.isLoading.value) return const Loading();
        if (controller.items.isEmpty) return const EmptyState(icon: Iconsax.volume_high, message: 'Belum ada pengumuman.');
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView.separated(
            padding: EdgeInsets.all(20.w),
            itemCount: controller.items.length,
            separatorBuilder: (_, i) => SizedBox(height: 12.h),
            itemBuilder: (_, i) {
              final a = controller.items[i];
              return Container(
                padding: EdgeInsets.all(16.w),
                decoration: softCard(radius: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (a.pinned) Padding(padding: EdgeInsets.only(right: 6.w), child: Icon(Iconsax.paperclip2, size: 14.sp, color: AppColors.warning)),
                    Expanded(child: Text(a.title, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 14.sp))),
                  ]),
                  if (a.publishedAt != null) Padding(padding: EdgeInsets.only(top: 2.h), child: Text(a.publishedAt!.split('T').first, style: TextStyle(color: AppColors.textMuted, fontSize: 11.5.sp))),
                  if (a.body != null && a.body!.isNotEmpty) Padding(padding: EdgeInsets.only(top: 8.h), child: Text(a.body!, style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp, height: 1.5))),
                ]),
              );
            },
          ),
        );
      }),
    );
  }
}
