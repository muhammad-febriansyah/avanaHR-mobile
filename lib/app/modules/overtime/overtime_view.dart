import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_toast.dart';
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
        return RefreshIndicator(
          onRefresh: controller.load,
          color: AppColors.primary,
          child: controller.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: 80.h),
                    const EmptyState(
                      icon: Iconsax.timer_1,
                      message: 'Belum ada pengajuan lembur.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 90.h),
                  itemCount: controller.items.length,
                  separatorBuilder: (_, i) => SizedBox(height: 10.h),
                  itemBuilder: (_, i) {
                    final o = controller.items[i];
                    return ContentCard(
                      child: Row(
                        children: [
                          const IconBubble(Iconsax.timer_1, AppColors.warning),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                if (o.reason != null && o.reason!.isNotEmpty)
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20.w,
          right: 20.w,
          top: 14.h,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24.h,
        ),
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
              ),
            ),
            SizedBox(height: 14.h),
            AppTextField(
              controller: hoursC,
              label: 'Jumlah Jam',
              hint: '0',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            SizedBox(height: 14.h),
            AppTextField(
              controller: reasonC,
              label: 'Alasan (opsional)',
              hint: 'Tulis alasan…',
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
