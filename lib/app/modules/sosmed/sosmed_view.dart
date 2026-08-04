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
import '../../data/services/auth_service.dart';
import '../../routes/app_pages.dart';
import 'sosmed_controller.dart';
import 'sosmed_leaderboard_view.dart';
import 'widgets/comments_sheet.dart';
import 'widgets/post_card.dart';

/// The employee wall: category chips, an infinite feed, and a compose button.
class SosmedView extends GetView<SosmedController> {
  const SosmedView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Ruang Kita',
      subtitle: 'Cerita, ide, dan apresiasi antar karyawan',
      showBack: false,
      actions: [
        HeaderAction(Iconsax.star_1, () => Get.toNamed(Routes.EOTM)),
        HeaderAction(
          Iconsax.crown_1,
          () => Get.to(() => const SosmedLeaderboardView()),
        ),
      ],
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
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 88.h),
              children: [
                _composerRow(context),
                SizedBox(height: 14.h),
                _categoryChips(),
                SizedBox(height: 12.h),
                _toolbar(),
                SizedBox(height: 14.h),
                if (controller.feedError.value != null)
                  Padding(
                    padding: EdgeInsets.only(top: 60.h),
                    child: Column(
                      children: [
                        EmptyState(
                          icon: Iconsax.cloud_cross,
                          message: controller.feedError.value!,
                        ),
                        TextButton.icon(
                          onPressed: controller.load,
                          icon: Icon(Iconsax.refresh, size: 16.sp),
                          label: Text(
                            'Coba lagi',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (controller.posts.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 60.h),
                    child: const EmptyState(
                      icon: Iconsax.message_text,
                      message: 'Belum ada postingan. Jadilah yang pertama!',
                    ),
                  )
                else
                  _feed(context),
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

  /// The "what's on your mind" row that opens the compose sheet.
  ///
  /// This replaced a floating button: the shell already pins the AI shortcut
  /// bottom-right, and two floating buttons in one corner crowd each other.
  Widget _composerRow(BuildContext context) {
    final name = Get.find<AuthService>().user.value?.name ?? '';

    return GestureDetector(
      onTap: () => _openCompose(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'Apa yang mau kamu bagikan?',
                style: TextStyle(fontSize: 13.5.sp, color: AppColors.textMuted),
              ),
            ),
            Icon(Iconsax.gallery, size: 19.sp, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  /// Sort tabs on the left, column picker on the right.
  Widget _toolbar() {
    return Obx(
      () => Row(
        children: [
          _sortTab('latest', 'Terbaru'),
          SizedBox(width: 6.w),
          _sortTab('trending', 'Trending'),
          const Spacer(),
          ...[1, 2].map((count) {
            final selected = controller.columns.value == count;

            return Padding(
              padding: EdgeInsets.only(left: 6.w),
              child: GestureDetector(
                onTap: () => controller.setColumns(count),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 30.w,
                  height: 30.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    count == 1 ? Iconsax.row_vertical : Iconsax.element_3,
                    size: 15.sp,
                    color: selected ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _sortTab(String value, String label) {
    final selected = controller.sort.value == value;

    return GestureDetector(
      onTap: () => controller.setSort(value),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(99.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  /// One column, or a masonry of two or three.
  ///
  /// Cards differ in height — a photo post is far taller than a one-liner — so
  /// a GridView with a fixed aspect ratio would leave ragged gaps. Dealing the
  /// posts round-robin into N columns keeps them tight without pulling in a
  /// staggered-grid package.
  Widget _feed(BuildContext context) {
    final columns = controller.columns.value;
    final posts = controller.posts;

    if (columns == 1) {
      return Column(
        children: posts
            .map(
              (post) => Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: _card(context, post, compact: false),
              ),
            )
            .toList(),
      );
    }

    final lanes = List.generate(columns, (_) => <Widget>[]);

    for (var i = 0; i < posts.length; i++) {
      lanes[i % columns].add(
        Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: _card(context, posts[i], compact: true),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < columns; i++) ...[
          if (i > 0) SizedBox(width: 10.w),
          Expanded(child: Column(children: lanes[i])),
        ],
      ],
    );
  }

  Widget _card(
    BuildContext context,
    SocialPostItem post, {
    required bool compact,
  }) {
    return PostCard(
      post: post,
      compact: compact,
      onLike: () => controller.toggleLike(post),
      onComment: () => _openPost(context, post, composer: true),
      onOpen: () => _openPost(context, post),
      onMenu: () => _openPostMenu(context, post),
    );
  }

  Widget _categoryChips() {
    return SizedBox(
      height: 34.h,
      child: Obx(() {
        final options = <SocialCategoryItem?>[null, ...controller.categories];
        // Read in the body, not in itemBuilder: lazily-built items fall outside
        // the Obx scope, so the chip highlight would not follow the selection.
        final active = controller.activeCategory.value;

        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: options.length,
          separatorBuilder: (_, _) => SizedBox(width: 8.w),
          itemBuilder: (_, i) {
            final category = options[i];
            final selected = active == category?.id;
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

  /// The post and its thread, raised over the feed.
  ///
  /// [composer] puts the cursor in the reply box on arrival — tapping the
  /// comment button should land on the box to type in, not on the first line of
  /// somebody else's thread.
  void _openPost(
    BuildContext context,
    SocialPostItem post, {
    bool composer = false,
  }) {
    showPostComments(context, post, focusComposer: composer);
  }

  /// Own post: edit or delete it. Someone else's: report it for HR to review.
  void _openPostMenu(BuildContext context, SocialPostItem post) {
    if (post.isMine) {
      _openOwnPostMenu(context, post);
      return;
    }

    _openReport(context, post);
  }

  /// Editing used to hang off the detail screen's action bar; with the screen
  /// gone this menu is where an author reaches their own post.
  void _openOwnPostMenu(BuildContext context, SocialPostItem post) {
    showAppSheet(
      context,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader('Postingan saya'),
            SizedBox(height: 6.h),
            _menuAction(
              icon: Iconsax.edit_2,
              label: 'Edit postingan',
              tone: AppColors.textPrimary,
              onTap: () {
                Get.back<void>();
                showPostEditSheet(context, post);
              },
            ),
            _menuAction(
              icon: Iconsax.trash,
              label: 'Hapus postingan',
              tone: AppColors.destructive,
              onTap: () {
                Get.back<void>();
                _confirmDelete(context, post);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuAction({
    required IconData icon,
    required String label,
    required Color tone,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, size: 18.sp, color: tone),
            SizedBox(width: 12.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w600,
                color: tone,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Reporting is the only lever an employee has over someone else's post —
  /// the wall publishes immediately, so this is what reaches HR.
  void _openReport(BuildContext context, SocialPostItem post) {
    final reasonC = TextEditingController();

    showAppFormSheet(
      context,
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 24.h),
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
            hintStyle: TextStyle(fontSize: 13.sp, color: AppColors.textMuted),
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
            final ok = await controller.reportPost(post, reasonC.text.trim());
            if (ok) Get.back();
          },
        ),
      ],
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

  /// A line of explanation where the category chips would have been. Amber
  /// rather than red: nothing is blocked, the post still sends.
  Widget _categoryNote(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.info_circle, size: 15.sp, color: AppColors.warning),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.sp,
                height: 1.45,
                color: AppColors.textPrimary.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
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

    showAppFormSheet(
      context,
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 24.h),
      children: [
        const SheetHeader('Buat Postingan'),
        SizedBox(height: 16.h),

        // An empty category list is a real state, not a glitch, and so is one
        // that failed to arrive. Both say so in words: a heading floating above
        // nothing reads as a field that broke.
        Obx(() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kategori',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              if (controller.loadingCategories.value)
                Text(
                  'Memuat kategori…',
                  style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted),
                )
              else if (controller.categoriesFailed.value)
                _categoryNote(
                  'Daftar kategori gagal dimuat. Postingan tetap bisa dikirim '
                  'tanpa kategori.',
                )
              else if (controller.categories.isEmpty)
                _categoryNote(
                  'Belum ada kategori di perusahaan ini. Postingan tetap bisa '
                  'dikirim tanpa kategori — minta admin HR menambahkannya '
                  'kalau dibutuhkan.',
                )
              else
                Wrap(
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
              SizedBox(height: 16.h),
            ],
          );
        }),

        TextField(
          controller: bodyC,
          maxLines: 5,
          maxLength: 500,
          style: TextStyle(fontSize: 14.sp),
          decoration: InputDecoration(
            hintText: 'Ceritakan idemu… semakin detail semakin bagus!',
            hintStyle: TextStyle(fontSize: 13.5.sp, color: AppColors.textMuted),
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
                final picked = await openFile(acceptedTypeGroups: [typeGroup]);
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
