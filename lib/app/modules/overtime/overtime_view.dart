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
import 'overtime_controller.dart';

class OvertimeView extends GetView<OvertimeController> {
  const OvertimeView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Lembur',
      subtitle: 'Ajukan & pantau lembur',
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
                            icon: Iconsax.timer_1,
                            message: 'Belum ada pengajuan lembur.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 90.h),
                        itemCount: controller.visibleItems.length,
                        separatorBuilder: (_, i) => SizedBox(height: 10.h),
                        itemBuilder: (_, i) {
                          final o = controller.visibleItems[i];
                          return ContentCard(
                            child: Row(
                              children: [
                                const IconBubble(
                                  Iconsax.timer_1,
                                  AppColors.warning,
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        o.timeRange != null
                                            ? '${o.hours} jam · ${o.timeRange}'
                                            : '${o.hours} jam',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.navy,
                                          fontSize: 13.5.sp,
                                        ),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        o.date,
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                      if (o.reason != null &&
                                          o.reason!.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(top: 2.h),
                                          child: Text(
                                            o.reason!,
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
                                SizedBox(width: 8.w),
                                StatusChip(o.status),
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
    final date = Rxn<DateTime>();
    final startTime = RxnString();
    final endTime = RxnString();
    final reasonC = TextEditingController();
    final now = DateTime.now();
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    showAppFormSheet(
      context,
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
      children: [
        const SheetHeader('Ajukan Lembur'),
        SizedBox(height: 18.h),
        Obx(
          () => AppDateField(
            label: 'Tanggal',
            value: date.value,
            onPick: (d) => date.value = d,
            firstDate: now.subtract(const Duration(days: 30)),
            lastDate: now.add(const Duration(days: 30)),
            required: true,
          ),
        ),
        SizedBox(height: 14.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Obx(
                () => AppTimeField(
                  label: 'Jam Mulai',
                  value: startTime.value,
                  onPick: (v) => startTime.value = v,
                  required: true,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Obx(
                () => AppTimeField(
                  label: 'Jam Selesai',
                  value: endTime.value,
                  onPick: (v) => endTime.value = v,
                  required: true,
                ),
              ),
            ),
          ],
        ),
        Obx(() {
          final hours = _hoursBetween(startTime.value, endTime.value);
          if (hours == null) {
            return const SizedBox.shrink();
          }

          final tooLong = hours > 12 || hours < 0.5;

          return Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Text(
              tooLong
                  ? 'Durasi ${_trim(hours)} jam — di luar batas 0,5–12 jam'
                  : 'Durasi ${_trim(hours)} jam',
              style: TextStyle(
                fontSize: 12.sp,
                color: tooLong ? AppColors.destructive : AppColors.textMuted,
              ),
            ),
          );
        }),
        SizedBox(height: 14.h),
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
              final start = startTime.value;
              final end = endTime.value;

              if (date.value == null || start == null || end == null) {
                AppToast.warning('Lengkapi tanggal, jam mulai & selesai.');
                return;
              }

              final hours = _hoursBetween(start, end);

              if (hours == null || hours < 0.5 || hours > 12) {
                AppToast.warning('Durasi lembur harus antara 0,5 dan 12 jam.');
                return;
              }

              final ok = await controller.submit(
                date: fmt(date.value!),
                startTime: start,
                endTime: end,
                reason: reasonC.text.trim().isEmpty
                    ? null
                    : reasonC.text.trim(),
              );
              if (ok) Get.back();
            },
          ),
        ),
      ],
    );
  }
}

/// Hours between two `HH:MM` values, mirroring the server: an end at or before
/// the start means the work ran past midnight, which is the usual shape for
/// evening overtime.
double? _hoursBetween(String? start, String? end) {
  if (start == null || end == null) {
    return null;
  }

  final from = start.split(':');
  final to = end.split(':');

  if (from.length < 2 || to.length < 2) {
    return null;
  }

  final startMinutes = int.parse(from[0]) * 60 + int.parse(from[1]);
  final endMinutes = int.parse(to[0]) * 60 + int.parse(to[1]);
  final diff = endMinutes - startMinutes;

  return (diff <= 0 ? diff + 24 * 60 : diff) / 60;
}

/// "2" rather than "2.0", but "2.5" kept intact.
String _trim(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
