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
                                        '${o.hours} jam',
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
    final hoursC = TextEditingController();
    final reasonC = TextEditingController();
    final now = DateTime.now();
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    showAppSheet(
      context,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            AppTextField(
              controller: hoursC,
              label: 'Jumlah Jam',
              hint: '0',
              icon: Iconsax.clock,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              required: true,
            ),
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
                  final hours = double.tryParse(hoursC.text.trim());
                  if (date.value == null || hours == null || hours <= 0) {
                    AppToast.warning('Lengkapi tanggal & jam.');
                    return;
                  }
                  final ok = await controller.submit(
                    date: fmt(date.value!),
                    hours: hours,
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
