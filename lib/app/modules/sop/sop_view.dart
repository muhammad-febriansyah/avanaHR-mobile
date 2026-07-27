import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/ess_models.dart';
import 'sop_controller.dart';

/// Read-only list of the company procedures this employee may open, mirroring
/// the web "SOP Perusahaan" screen. Tapping a card downloads the PDF and hands
/// it to a device viewer.
class SopView extends GetView<SopController> {
  const SopView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'SOP Perusahaan',
      subtitle: 'Prosedur resmi yang berlaku',
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Loading();
        }

        final visible = controller.visible;

        return RefreshIndicator(
          onRefresh: controller.load,
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
            children: [
              _SearchBox(controller: controller),
              if (controller.categories.length > 1) ...[
                SizedBox(height: 12.h),
                _CategoryChips(controller: controller),
              ],
              SizedBox(height: 16.h),
              if (visible.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 60.h),
                  child: EmptyState(
                    icon: Iconsax.book,
                    message: controller.items.isEmpty
                        ? 'Belum ada SOP yang dipublikasikan untuk Anda.'
                        : 'Tidak ada SOP yang cocok dengan pencarian.',
                  ),
                )
              else
                ...visible.map(
                  (sop) => Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: _SopCard(
                      sop: sop,
                      busy: controller.busyId.value == sop.id,
                      onTap: () => controller.openPdf(sop),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final SopController controller;

  const _SearchBox({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: (value) => controller.search.value = value,
      style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Cari SOP…',
        hintStyle: TextStyle(fontSize: 14.sp, color: AppColors.textMuted),
        prefixIcon: Icon(Iconsax.search_normal, size: 18.sp),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
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
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final SopController controller;

  const _CategoryChips({required this.controller});

  @override
  Widget build(BuildContext context) {
    final options = ['', ...controller.categories];

    return SizedBox(
      height: 34.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => SizedBox(width: 8.w),
        itemBuilder: (_, i) {
          final value = options[i];
          final selected = controller.category.value == value;

          return GestureDetector(
            onTap: () => controller.category.value = value,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.muted,
                borderRadius: BorderRadius.circular(99.r),
              ),
              child: Text(
                value.isEmpty ? 'Semua' : value,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SopCard extends StatelessWidget {
  final SopItem sop;
  final bool busy;
  final VoidCallback onTap;

  const _SopCard({required this.sop, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: sop.hasFile && !busy ? onTap : null,
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11.r),
              ),
              child: busy
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(Iconsax.book, size: 19.sp, color: AppColors.primary),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sop.title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    [
                      sop.category,
                      if (sop.subtitle.isNotEmpty) sop.subtitle,
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if ((sop.summary ?? '').isNotEmpty) ...[
                    SizedBox(height: 7.h),
                    Text(
                      sop.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        height: 1.45,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  if (sop.effectiveDate != null) ...[
                    SizedBox(height: 7.h),
                    Text(
                      'Berlaku ${sop.effectiveDate}',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (sop.hasFile)
              Icon(
                Iconsax.document_download,
                size: 18.sp,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}
