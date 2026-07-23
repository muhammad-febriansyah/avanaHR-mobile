import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/ess_models.dart';
import 'announcement_controller.dart';

const _accent = Color(0xFFEA580C);

class AnnouncementView extends GetView<AnnouncementController> {
  const AnnouncementView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Pengumuman',
      subtitle: 'Info terbaru',
      showBack: false,
      // Light canvas behind the list so each white card reads as a distinct
      // container without needing a shadow or border.
      child: Container(
        color: AppColors.background,
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
                        icon: Iconsax.volume_high,
                        message: 'Belum ada pengumuman.',
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      20.w,
                      20.h,
                      20.w,
                      24.h + AppPage.bottomNavClearance(context),
                    ),
                    itemCount: controller.items.length,
                    separatorBuilder: (_, i) => SizedBox(height: 12.h),
                    itemBuilder: (_, i) => _card(
                      controller.items[i],
                      () => _openDetail(context, controller.items[i]),
                    ),
                  ),
          );
        }),
      ),
    );
  }

  Widget _card(AnnouncementItem a, VoidCallback onTap) {
    return ContentCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBubble(
                a.pinned ? Iconsax.paperclip_2 : Iconsax.volume_high,
                _accent,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (a.pinned) ...[_pinBadge(), SizedBox(height: 5.h)],
                    Text(
                      a.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                        fontSize: 14.sp,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (a.body != null && a.body!.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Text(
              a.body!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5.sp,
                height: 1.45,
              ),
            ),
          ],
          SizedBox(height: 12.h),
          Row(
            children: [
              if (a.category != null && a.category!.isNotEmpty)
                _categoryChip(a.category!),
              const Spacer(),
              if (a.publishedAt != null) ...[
                Icon(
                  Iconsax.calendar_1,
                  size: 13.sp,
                  color: AppColors.textMuted,
                ),
                SizedBox(width: 5.w),
                Text(
                  formatTanggal(a.publishedAt),
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _pinBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.paperclip_2, size: 10.sp, color: _accent),
          SizedBox(width: 4.w),
          Text(
            'DISEMATKAN',
            style: TextStyle(
              color: _accent,
              fontSize: 8.5.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String category) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Full announcement in a bottom sheet — the card truncates the body, this
  /// shows all of it.
  void _openDetail(BuildContext context, AnnouncementItem a) {
    showAppSheet(
      context,
      scrollable: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 24.h),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHeader('Pengumuman'),
              SizedBox(height: 14.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBubble(
                    a.pinned ? Iconsax.paperclip_2 : Iconsax.volume_high,
                    _accent,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (a.pinned) ...[_pinBadge(), SizedBox(height: 6.h)],
                        Text(
                          a.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                            fontSize: 16.sp,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  if (a.category != null && a.category!.isNotEmpty) ...[
                    _categoryChip(a.category!),
                    SizedBox(width: 10.w),
                  ],
                  if (a.publishedAt != null) ...[
                    Icon(
                      Iconsax.calendar_1,
                      size: 13.sp,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      formatTanggal(a.publishedAt),
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              if (a.body != null && a.body!.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: Divider(height: 1, color: AppColors.border),
                ),
                Text(
                  a.body!,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5.sp,
                    height: 1.6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
