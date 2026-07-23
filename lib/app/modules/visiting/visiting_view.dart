import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/ui.dart';
import '../../routes/app_pages.dart';
import 'visiting_controller.dart';

class VisitingView extends GetView<VisitingController> {
  const VisitingView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Visiting Pekerjaan',
      subtitle: 'Catat kunjungan kerja',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(Routes.VISITING_REPORT),
        backgroundColor: AppColors.primary,
        icon: const Icon(Iconsax.location_add, color: Colors.white),
        label: const Text('Lapor', style: TextStyle(color: Colors.white)),
      ),
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Loading();
        }
        final visits = controller.items;
        final searching = controller.query.value.trim().isNotEmpty;
        return Column(
          children: [
            if (visits.isNotEmpty || searching)
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 4.h),
                child: _VisitSearchField(
                  onChanged: (v) => controller.query.value = v,
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.load,
                color: AppColors.primary,
                child: visits.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        children: [
                          SizedBox(height: 80.h),
                          EmptyState(
                            icon: searching ? Iconsax.search_normal_1 : Iconsax.location,
                            message: searching
                                ? 'Tidak ada kunjungan yang cocok.'
                                : 'Belum ada kunjungan.',
                          ),
                        ],
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.pixels >=
                                  n.metrics.maxScrollExtent - 300.h &&
                              controller.hasMore &&
                              !controller.loadingMore.value) {
                            controller.loadMore();
                          }
                          return false;
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 90.h),
                          itemCount:
                              visits.length +
                              (controller.loadingMore.value ? 1 : 0),
                          separatorBuilder: (_, i) => SizedBox(height: 10.h),
                          itemBuilder: (_, i) {
                            if (i >= visits.length) {
                              return Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                child: Center(
                                  child: SizedBox(
                                    width: 22.w,
                                    height: 22.w,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              );
                            }
                            final v = visits[i];
                            return ContentCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const IconBubble(
                                Iconsax.location,
                                Color(0xFFE11D48),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      v.location,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navy,
                                        fontSize: 13.5.sp,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      v.visitDate,
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                    if (v.clientName != null &&
                                        v.clientName!.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(top: 2.h),
                                        child: Text(
                                          'Klien: ${v.clientName}',
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                      ),
                                    if (v.purpose != null &&
                                        v.purpose!.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(top: 2.h),
                                        child: Text(
                                          v.purpose!,
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8.w),
                              StatusChip(v.status),
                            ],
                          ),
                          if (v.photoUrls.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 10.h),
                              child: SizedBox(
                                height: 120.h,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: v.photoUrls.length,
                                  separatorBuilder: (_, _) =>
                                      SizedBox(width: 8.w),
                                  itemBuilder: (_, i) => ClipRRect(
                                    borderRadius: BorderRadius.circular(10.r),
                                    child: CachedNetworkImage(
                                      imageUrl: v.photoUrls[i],
                                      // A lone photo fills the card as before;
                                      // several become a scrollable strip.
                                      width: v.photoUrls.length == 1
                                          ? MediaQuery.of(context).size.width -
                                                80.w
                                          : 150.w,
                                      height: 120.h,
                                      fit: BoxFit.cover,
                                      // Decode at strip size, not full res, to
                                      // keep memory flat with many thumbnails.
                                      memCacheHeight: 240,
                                      fadeInDuration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      placeholder: (_, _) => Container(
                                        color: AppColors.muted,
                                      ),
                                      errorWidget: (_, _, _) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                          },
                        ),
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Compact search box for the visit list — filters by location, client, or
/// purpose. Mirrors the muted, pill-radius styling used across the app's
/// filter controls. Stateful so its controller survives the list's Obx
/// rebuilds and the field keeps focus while typing.
class _VisitSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;

  const _VisitSearchField({required this.onChanged});

  @override
  State<_VisitSearchField> createState() => _VisitSearchFieldState();
}

class _VisitSearchFieldState extends State<_VisitSearchField> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(
            Iconsax.search_normal_1,
            size: 16.sp,
            color: AppColors.textMuted,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: TextField(
              controller: _c,
              onChanged: widget.onChanged,
              style: TextStyle(fontSize: 13.sp, color: AppColors.textPrimary),
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Cari lokasi, klien, atau tujuan…',
                hintStyle: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _c,
            builder: (_, v, _) => v.text.isEmpty
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: () {
                      _c.clear();
                      widget.onChanged('');
                    },
                    child: Icon(
                      Iconsax.close_circle,
                      size: 16.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
