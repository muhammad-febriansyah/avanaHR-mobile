import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/filter_chips.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/ui.dart';
import 'permission_controller.dart';

class PermissionView extends GetView<PermissionController> {
  const PermissionView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Izin',
      subtitle: 'Ajukan & pantau izin',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Iconsax.add, color: Colors.white),
        label: const Text('Ajukan', style: TextStyle(color: Colors.white)),
      ),
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Loading();
        }
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 4.h),
              child: FilterChips(
                options: kStatusFilterOptions,
                selected: controller.statusFilter.value,
                onSelected: (v) => controller.statusFilter.value = v,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.load,
                color: AppColors.primary,
                child: controller.visibleItems.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        children: [
                          SizedBox(height: 80.h),
                          const EmptyState(
                            icon: Iconsax.calendar_remove,
                            message: 'Belum ada pengajuan izin.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 90.h),
                        itemCount: controller.visibleItems.length,
                        separatorBuilder: (_, i) => SizedBox(height: 10.h),
                        itemBuilder: (_, i) {
                          final p = controller.visibleItems[i];
                          final time = p.startTime != null
                              ? ' · ${p.startTime} - ${p.endTime}'
                              : '';
                          return ContentCard(
                            child: Row(
                              children: [
                                const IconBubble(
                                  Iconsax.calendar_remove,
                                  Color(0xFF7C3AED),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.type,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.navy,
                                          fontSize: 13.5.sp,
                                        ),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        '${p.dateLabel}$time',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                StatusChip(p.status),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }

  void _openSheet(BuildContext context) {
    final startDate = Rxn<DateTime>();
    final endDate = Rxn<DateTime>();
    final typeC = TextEditingController();
    final start = RxnString();
    final end = RxnString();
    final reasonC = TextEditingController();
    String fmtD(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    /// Times narrow a single day to part of it; across a range the izin covers
    /// whole days, and the server rejects times there.
    bool isSingleDay() =>
        startDate.value != null &&
        endDate.value != null &&
        fmtD(startDate.value!) == fmtD(endDate.value!);

    showAppSheet(
      context,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHeader('Ajukan Izin'),
            SizedBox(height: 18.h),
            Row(
              children: [
                Expanded(
                  child: Obx(
                    () => AppDateField(
                      label: 'Tanggal Mulai',
                      value: startDate.value,
                      onPick: (d) {
                        startDate.value = d;
                        // Keep the range coherent: an end before the new start
                        // is meaningless, so collapse it onto the start.
                        final currentEnd = endDate.value;
                        if (currentEnd == null || currentEnd.isBefore(d)) {
                          endDate.value = d;
                        }
                      },
                      required: true,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Obx(
                    () => AppDateField(
                      label: 'Tanggal Selesai',
                      value: endDate.value,
                      onPick: (d) => endDate.value = d,
                      required: true,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            AppTextField(
              controller: typeC,
              label: 'Jenis Izin',
              hint: 'mis. keluar kantor',
              icon: Iconsax.category,
              required: true,
            ),
            SizedBox(height: 14.h),
            Obx(
              () => !isSingleDay()
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: EdgeInsets.only(bottom: 14.h),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppTimeField(
                              label: 'Jam Mulai',
                              value: start.value,
                              onPick: (t) => start.value = t,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: AppTimeField(
                              label: 'Jam Selesai',
                              value: end.value,
                              onPick: (t) => end.value = t,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            AppTextField(
              controller: reasonC,
              label: 'Alasan (opsional)',
              hint: 'Tulis alasan…',
              icon: Iconsax.note_1,
              maxLines: 2,
            ),
            SizedBox(height: 22.h),
            Obx(
              () => AppSubmitButton(
                loading: controller.submitting.value,
                onPressed: () async {
                  if (startDate.value == null ||
                      endDate.value == null ||
                      typeC.text.trim().isEmpty) {
                    AppToast.warning('Lengkapi tanggal & jenis izin.');
                    return;
                  }
                  if (endDate.value!.isBefore(startDate.value!)) {
                    AppToast.warning(
                      'Tanggal selesai tidak boleh sebelum tanggal mulai.',
                    );
                    return;
                  }

                  // Only a single-day izin carries times; anything typed before
                  // the range grew is dropped rather than sent to be rejected.
                  final singleDay = isSingleDay();

                  final ok = await controller.submit(
                    startDate: fmtD(startDate.value!),
                    endDate: fmtD(endDate.value!),
                    type: typeC.text.trim(),
                    startTime: singleDay ? start.value : null,
                    endTime: singleDay ? end.value : null,
                    reason: reasonC.text.trim().isEmpty
                        ? null
                        : reasonC.text.trim(),
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
