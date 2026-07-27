import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/ess_models.dart';
import '../../routes/app_pages.dart';
import 'sosmed_controller.dart';
import 'sosmed_detail_view.dart';
import 'sosmed_leaderboard_view.dart';
import 'widgets/post_card.dart';

/// The employee wall: category chips, an infinite feed, and a compose button.
class SosmedView extends GetView<SosmedController> {
  const SosmedView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Sosmed',
      subtitle: 'Cerita, ide, dan apresiasi antar karyawan',
      showBack: false,
      actions: [
        HeaderAction(Iconsax.star_1, () => Get.toNamed(Routes.EOTM)),
        HeaderAction(
          Iconsax.crown_1,
          () => Get.to(() => const SosmedLeaderboardView()),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCompose(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Iconsax.edit, color: Colors.white),
        label: const Text('Posting', style: TextStyle(color: Colors.white)),
      ),
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Loading();
        }

        return RefreshIndicator(
          onRefresh: controller.load,
          color: AppColors.primary,
          child: NotificationListener<ScrollNotification>(
            // Pull the next page in a little before the very bottom so the
            // feed keeps flowing instead of stalling at the last card.
            onNotification: (notification) {
              final metrics = notification.metrics;
              if (metrics.pixels >= metrics.maxScrollExtent - 400) {
                controller.loadMore();
              }
              return false;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 96.h),
              children: [
                _categoryChips(),
                SizedBox(height: 14.h),
                if (controller.posts.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 60.h),
                    child: const EmptyState(
                      icon: Iconsax.message_text,
                      message: 'Belum ada postingan. Jadilah yang pertama!',
                    ),
                  )
                else
                  ...controller.posts.map(
                    (post) => Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: PostCard(
                        post: post,
                        onLike: () => controller.toggleLike(post),
                        onComment: () => _openDetail(post),
                        onOpen: () => _openDetail(post),
                        onMenu: () => _openPostMenu(context, post),
                      ),
                    ),
                  ),
                if (controller.isLoadingMore.value)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 18.h),
                    child: Center(
                      child: SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _categoryChips() {
    return SizedBox(
      height: 34.h,
      child: Obx(() {
        final options = <SocialCategoryItem?>[null, ...controller.categories];

        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: options.length,
          separatorBuilder: (_, _) => SizedBox(width: 8.w),
          itemBuilder: (_, i) {
            final category = options[i];
            final selected = controller.activeCategory.value == category?.id;
            final accent = category == null
                ? AppColors.primary
                : _hexColor(category.color);

            return GestureDetector(
              onTap: () => controller.filterBy(category?.id),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? accent : AppColors.muted,
                  borderRadius: BorderRadius.circular(99.r),
                ),
                child: Text(
                  category?.name ?? 'Semua',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  /// The full post with its thread. Commenting lives there now, so the feed
  /// stays a scan surface rather than a place to read long threads.
  void _openDetail(SocialPostItem post) {
    Get.to(() => SosmedDetailView(post: post))?.then((_) => controller.load());
  }

  /// Own post: delete it. Someone else's: report it for HR to review.
  void _openPostMenu(BuildContext context, SocialPostItem post) {
    if (post.isMine) {
      _confirmDelete(context, post);
      return;
    }

    _openReport(context, post);
  }

  /// Reporting is the only lever an employee has over someone else's post —
  /// the wall publishes immediately, so this is what reaches HR.
  void _openReport(BuildContext context, SocialPostItem post) {
    final reasonC = TextEditingController();

    showAppSheet(
      context,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHeader('Laporkan postingan'),
            SizedBox(height: 10.h),
            Text(
              'Tim HR akan meninjau postingan ini. Pelapor tidak ditampilkan ke pemilik postingan.',
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            SizedBox(height: 14.h),
            TextField(
              controller: reasonC,
              maxLines: 3,
              maxLength: 300,
              style: TextStyle(fontSize: 13.5.sp),
              decoration: InputDecoration(
                hintText: 'Alasan (opsional)',
                hintStyle: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.textMuted,
                ),
                counterText: '',
                filled: true,
                fillColor: AppColors.muted,
                contentPadding: EdgeInsets.all(12.w),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppColors.primary, width: 1.4),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            AppSubmitButton(
              label: 'Kirim Laporan',
              loading: false,
              onPressed: () async {
                final ok = await controller.reportPost(
                  post,
                  reasonC.text.trim(),
                );
                if (ok) Get.back();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, SocialPostItem post) {
    showAppSheet(
      context,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHeader('Hapus postingan?'),
            SizedBox(height: 10.h),
            Text(
              'Postingan beserta semua like dan komentarnya akan dihapus permanen.',
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            SizedBox(height: 20.h),
            AppSubmitButton(
              label: 'Hapus',
              loading: false,
              onPressed: () async {
                final ok = await controller.deletePost(post);
                if (ok) Get.back();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Compose sheet: category chip, text (max 500), optional photo.
  void _openCompose(BuildContext context) {
    final bodyC = TextEditingController();
    final imagePath = RxnString();
    final imageName = RxnString();
    final categoryId = Rxn<int>();
    final length = 0.obs;

    bodyC.addListener(() => length.value = bodyC.text.characters.length);

    showAppSheet(
      context,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHeader('Buat Postingan'),
            SizedBox(height: 16.h),

            Text(
              'Kategori',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Obx(
              () => Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: controller.categories.map((category) {
                  final selected = categoryId.value == category.id;
                  final accent = _hexColor(category.color);

                  return GestureDetector(
                    onTap: () =>
                        categoryId.value = selected ? null : category.id,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? accent.withValues(alpha: 0.12)
                            : AppColors.muted,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: selected ? accent : AppColors.textMuted,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            SizedBox(height: 16.h),
            TextField(
              controller: bodyC,
              maxLines: 5,
              maxLength: 500,
              style: TextStyle(fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: 'Ceritakan idemu… semakin detail semakin bagus!',
                hintStyle: TextStyle(
                  fontSize: 13.5.sp,
                  color: AppColors.textMuted,
                ),
                counterText: '',
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: EdgeInsets.all(14.w),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppColors.primary, width: 1.4),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Obx(
                () => Text(
                  '${length.value}/500',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: length.value > 500
                        ? AppColors.destructive
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ),

            SizedBox(height: 12.h),
            Obx(() {
              final path = imagePath.value;

              if (path == null) {
                return InkWell(
                  borderRadius: BorderRadius.circular(12.r),
                  onTap: () async {
                    const typeGroup = XTypeGroup(
                      label: 'Foto',
                      extensions: ['jpg', 'jpeg', 'png', 'webp'],
                    );
                    final picked = await openFile(
                      acceptedTypeGroups: [typeGroup],
                    );
                    if (picked != null) {
                      imagePath.value = picked.path;
                      imageName.value = picked.name;
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 18.h),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Iconsax.gallery_add,
                          size: 22.sp,
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'Tambah foto (opsional)',
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: Image.file(
                      File(path),
                      width: double.infinity,
                      height: 150.h,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8.h,
                    right: 8.w,
                    child: GestureDetector(
                      onTap: () {
                        imagePath.value = null;
                        imageName.value = null;
                      },
                      child: Container(
                        padding: EdgeInsets.all(6.w),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(99.r),
                        ),
                        child: Icon(
                          Iconsax.close_circle,
                          size: 16.sp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),

            SizedBox(height: 20.h),
            Obx(
              () => AppSubmitButton(
                label: 'Kirim',
                loading: controller.submitting.value,
                onPressed: () async {
                  final body = bodyC.text.trim();

                  if (body.isEmpty) {
                    AppToast.warning('Tulis dulu isi postingannya.');
                    return;
                  }

                  final ok = await controller.createPost(
                    body: body,
                    categoryId: categoryId.value,
                    imagePath: imagePath.value,
                  );
                  if (ok) Get.back();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `#RRGGBB` from the category master into a Flutter colour, falling back to
/// the brand primary when the stored value is unusable.
Color hexColor(String? hex) => _hexColor(hex);

Color _hexColor(String? hex) {
  final value = (hex ?? '').replaceAll('#', '');

  if (value.length != 6) {
    return AppColors.primary;
  }

  final parsed = int.tryParse(value, radix: 16);

  return parsed == null ? AppColors.primary : Color(0xFF000000 | parsed);
}
