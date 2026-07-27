import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_toast.dart';
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
              if (a.attachment != null) ...[
                if (a.category != null && a.category!.isNotEmpty)
                  SizedBox(width: 8.w),
                _attachmentChip(a.attachment!),
              ],
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

  /// Marks on the list card that the announcement carries a file, so the user
  /// knows the detail sheet has something to open.
  Widget _attachmentChip(AnnouncementAttachment file) {
    final size = file.sizeLabel;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            file.isImage ? Iconsax.gallery : Iconsax.document_text,
            size: 11.sp,
            color: _accent,
          ),
          SizedBox(width: 4.w),
          Text(
            size.isEmpty ? file.kindLabel : '${file.kindLabel} · $size',
            style: TextStyle(
              color: _accent,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// The attached file inside the detail sheet: images preview inline, anything
  /// else shows a placeholder. Either way it opens in an external viewer, which
  /// is also where the user downloads it from.
  Widget _attachmentBlock(AnnouncementAttachment file) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Divider(height: 1, color: AppColors.border),
        ),
        Text(
          'Lampiran',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
            fontSize: 13.sp,
          ),
        ),
        SizedBox(height: 10.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(14.r),
          child: file.isImage
              ? CachedNetworkImage(
                  imageUrl: file.url,
                  width: double.infinity,
                  height: 220.h,
                  fit: BoxFit.cover,
                  memCacheHeight: 720,
                  placeholder: (_, _) =>
                      Container(height: 220.h, color: AppColors.muted),
                  errorWidget: (_, _, _) => _previewFallback(
                    Iconsax.gallery_slash,
                    'Gambar gagal dimuat',
                  ),
                )
              : _previewFallback(
                  Iconsax.document_text,
                  'Berkas ${file.kindLabel}',
                ),
        ),
        SizedBox(height: 10.h),
        Text(
          file.sizeLabel.isEmpty
              ? (file.name ?? file.kindLabel)
              : '${file.name ?? file.kindLabel} · ${file.sizeLabel}',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
        ),
        SizedBox(height: 12.h),
        AppSubmitButton(
          label: 'Buka / Unduh',
          loading: false,
          onPressed: () => _openAttachment(file),
        ),
      ],
    );
  }

  Widget _previewFallback(IconData icon, String label) {
    return Container(
      width: double.infinity,
      height: 170.h,
      color: AppColors.muted,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 42.sp, color: AppColors.textMuted),
          SizedBox(height: 10.h),
          Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  /// Hand the file to the OS. Tries an external app first, then an in-app tab,
  /// so a missing default browser doesn't dead-end the user.
  Future<void> _openAttachment(AnnouncementAttachment file) async {
    final uri = Uri.tryParse(file.url);
    if (uri == null) {
      AppToast.error('URL lampiran tidak valid.');

      return;
    }

    for (final mode in const [
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
    ]) {
      try {
        if (await launchUrl(uri, mode: mode)) {
          return;
        }
      } catch (_) {
        // Try the next launch mode.
      }
    }

    AppToast.error('Tidak ada aplikasi untuk membuka lampiran.');
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
              if (a.attachment != null) _attachmentBlock(a.attachment!),
            ],
          ),
        ),
      ),
    );
  }
}
