import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/ess_models.dart';
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
      child: Column(
        children: [
          // Search + date filter stay mounted across reloads, so typing never
          // loses focus and the day filter is always reachable.
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 4.h),
            child: Column(
              children: [
                _VisitSearchField(
                  onChanged: (v) => controller.query.value = v,
                ),
                SizedBox(height: 10.h),
                _DateFilterBar(controller: controller),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Loading();
              }
              final visits = controller.items;
              final searching = controller.query.value.trim().isNotEmpty;
              return RefreshIndicator(
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
                            icon: searching
                                ? Iconsax.search_normal_1
                                : Iconsax.location,
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
                            return _VisitCard(
                              visit: visits[i],
                              controller: controller,
                            );
                          },
                        ),
                      ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Day filter for the visit list. Defaults to today (kept light); tap the pill
/// to pick another date, or "Semua" to drop the filter and see every visit.
class _DateFilterBar extends StatelessWidget {
  final VisitingController controller;

  const _DateFilterBar({required this.controller});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  bool _isToday(DateTime d) {
    final n = DateTime.now();

    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.selectedDate.value ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) {
      controller.setDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final d = controller.selectedDate.value;
      final reloading = controller.reloading.value;
      final active = d != null;
      final label = d == null
          ? 'Semua tanggal'
          : (_isToday(d)
                ? 'Hari ini · ${d.day} ${_months[d.month - 1]}'
                : '${d.day} ${_months[d.month - 1]} ${d.year}');

      return Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _pick(context),
              child: Container(
                height: 40.h,
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.muted,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Iconsax.calendar_1,
                      size: 15.sp,
                      color: active ? AppColors.primary : AppColors.textMuted,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (reloading)
                      SizedBox(
                        width: 14.w,
                        height: 14.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    else
                      Icon(
                        Iconsax.arrow_down_1,
                        size: 14.sp,
                        color: active ? AppColors.primary : AppColors.textMuted,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (active) ...[
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: () => controller.setDate(null),
              child: Container(
                height: 40.h,
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  'Semua',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    });
  }
}

/// One visit in the list: header, visit photos, and the task checklist with
/// before/after evidence.
class _VisitCard extends StatelessWidget {
  final FieldVisitItem visit;
  final VisitingController controller;

  const _VisitCard({required this.visit, required this.controller});

  static Widget _sectionLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13.sp, color: AppColors.textMuted),
        SizedBox(width: 6.w),
        Text(
          text,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = visit;
    // Each visit sits in its own flat white card so it reads as a distinct list
    // item, separated by the gap over the page's light background.
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBubble(Iconsax.location, Color(0xFFE11D48)),
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
                    if (v.clientName != null && v.clientName!.isNotEmpty)
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
                    if (v.purpose != null && v.purpose!.isNotEmpty)
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
          if (v.tasks.isNotEmpty) ...[
            SizedBox(height: 14.h),
            _sectionLabel(Iconsax.task_square, 'TASKLIST PEKERJAAN'),
            SizedBox(height: 8.h),
            for (final t in v.tasks)
              _TaskTile(visit: v, task: t, controller: controller),
          ],
        ],
      ),
    );
  }
}

/// One task row: title, its before photo, and the after photo — or a button to
/// add the after photo when it hasn't been captured yet.
class _TaskTile extends StatelessWidget {
  final FieldVisitItem visit;
  final VisitTask task;
  final VisitingController controller;

  const _TaskTile({
    required this.visit,
    required this.task,
    required this.controller,
  });

  Future<void> _pickAfter(BuildContext context) async {
    showAppSheet<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            margin: EdgeInsets.symmetric(vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
          _sourceTile(context, Iconsax.camera, 'Kamera', ImageSource.camera),
          _sourceTile(context, Iconsax.gallery, 'Galeri', ImageSource.gallery),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _sourceTile(
    BuildContext ctx,
    IconData icon,
    String text,
    ImageSource src,
  ) {
    return ListTile(
      leading: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20.sp),
      ),
      title: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
          fontSize: 14.sp,
        ),
      ),
      onTap: () async {
        Navigator.pop(ctx);
        final img = await ImagePicker().pickImage(
          source: src,
          imageQuality: 70,
          maxWidth: 1600,
        );
        if (img != null) {
          controller.uploadTaskAfter(visit.id, task.id, img.path);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                task.isDone ? Iconsax.tick_square : Iconsax.task_square,
                size: 16.sp,
                color: task.isDone ? AppColors.success : AppColors.textMuted,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _beforeSlot()),
              SizedBox(width: 10.w),
              Expanded(child: _afterSlot(context)),
            ],
          ),
          if (task.photoNote != null && task.photoNote!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              task.photoNote!,
              style: TextStyle(fontSize: 11.5.sp, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _beforeSlot() {
    return _labeledSlot(
      'BEFORE',
      task.beforeUrl != null && task.beforeUrl!.isNotEmpty
          ? _thumb(task.beforeUrl!)
          : _placeholder('Tidak ada'),
    );
  }

  Widget _afterSlot(BuildContext context) {
    return Obx(() {
      // Touch .length so this Obx rebuilds when the uploading set changes.
      controller.uploadingAfter.length;
      final busy = controller.isUploadingAfter(task.id);

      Widget child;
      if (busy) {
        child = _box(
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          ),
        );
      } else if (task.hasAfter) {
        child = _thumb(task.afterUrl!);
      } else {
        child = InkWell(
          borderRadius: BorderRadius.circular(10.r),
          onTap: () => _pickAfter(context),
          child: _box(
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.camera, size: 18.sp, color: AppColors.primary),
                SizedBox(height: 4.h),
                Text(
                  'Tambah After',
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            dashed: true,
          ),
        );
      }

      return _labeledSlot('AFTER', child);
    });
  }

  Widget _labeledSlot(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.textMuted,
          ),
        ),
        SizedBox(height: 5.h),
        child,
      ],
    );
  }

  Widget _thumb(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.r),
      child: CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        height: 84.h,
        fit: BoxFit.cover,
        memCacheHeight: 200,
        placeholder: (_, _) => Container(
          height: 84.h,
          color: AppColors.surface,
        ),
        errorWidget: (_, _, _) => _placeholder('Gagal'),
      ),
    );
  }

  Widget _placeholder(String text) {
    return _box(
      Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 10.5.sp, color: AppColors.textMuted),
        ),
      ),
    );
  }

  Widget _box(Widget child, {bool dashed = false}) {
    return Container(
      width: double.infinity,
      height: 84.h,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10.r),
        border: dashed
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
              )
            : null,
      ),
      child: child,
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
    OutlineInputBorder pill() => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14.r),
      borderSide: BorderSide.none,
    );

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _c,
      builder: (_, value, _) => TextField(
        controller: _c,
        onChanged: widget.onChanged,
        style: TextStyle(fontSize: 13.5.sp, color: AppColors.textPrimary),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.primaryLight,
          hintText: 'Cari lokasi, klien, atau tujuan…',
          hintStyle: TextStyle(fontSize: 13.sp, color: AppColors.textMuted),
          prefixIcon: Icon(
            Iconsax.search_normal_1,
            size: 18.sp,
            color: AppColors.primary,
          ),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(
                    Iconsax.close_circle,
                    size: 18.sp,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () {
                    _c.clear();
                    widget.onChanged('');
                  },
                ),
          contentPadding: EdgeInsets.symmetric(vertical: 14.h),
          border: pill(),
          enabledBorder: pill(),
          focusedBorder: pill(),
        ),
      ),
    );
  }
}
