import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/ess_models.dart';
import 'attendance_correction_controller.dart';

class AttendanceCorrectionView extends GetView<AttendanceCorrectionController> {
  const AttendanceCorrectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Koreksi Absen',
      subtitle: 'Ajukan perbaikan jam absen',
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
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  children: [
                    SizedBox(height: 80.h),
                    const EmptyState(
                      icon: Iconsax.clock,
                      message: 'Belum ada pengajuan koreksi absen.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 90.h),
                  itemCount: controller.items.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10.h),
                  itemBuilder: (_, i) => _card(controller.items[i]),
                ),
        );
      }),
    );
  }

  Widget _card(AttendanceCorrectionItem c) {
    final times = <String>[
      if (c.clockIn != null) 'Masuk ${c.clockIn}',
      if (c.clockOut != null) 'Pulang ${c.clockOut}',
    ].join(' · ');

    return ContentCard(
      child: Row(
        children: [
          const IconBubble(Iconsax.clock, Color(0xFF4F46E5)),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.date,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                    fontSize: 13.5.sp,
                  ),
                ),
                if (times.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    times,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
                if (c.reason != null && c.reason!.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    c.reason!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8.w),
          StatusChip(c.status),
        ],
      ),
    );
  }

  void _openSheet(BuildContext context) {
    final date = Rxn<DateTime>();
    final clockIn = Rxn<String>();
    final clockOut = Rxn<String>();
    final reasonC = TextEditingController();
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
            const SheetHeader('Ajukan Koreksi Absen'),
            SizedBox(height: 6.h),
            Text(
              'Isi jam yang perlu diperbaiki. Persetujuan dikirim ke atasan.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
            ),
            SizedBox(height: 16.h),
            Obx(
              () => AppDateField(
                label: 'Tanggal',
                value: date.value,
                onPick: (d) => date.value = d,
                required: true,
              ),
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: Obx(
                    () => AppTimeField(
                      label: 'Jam Masuk',
                      value: clockIn.value,
                      onPick: (t) => clockIn.value = t,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Obx(
                    () => AppTimeField(
                      label: 'Jam Pulang',
                      value: clockOut.value,
                      onPick: (t) => clockOut.value = t,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            AppTextField(
              controller: reasonC,
              label: 'Alasan',
              hint: 'Mis. lupa clock in',
              maxLines: 2,
              required: true,
            ),
            SizedBox(height: 22.h),
            Obx(
              () => AppSubmitButton(
                loading: controller.submitting.value,
                onPressed: () async {
                  if (date.value == null) {
                    AppToast.warning('Pilih tanggal.');
                    return;
                  }
                  if (clockIn.value == null && clockOut.value == null) {
                    AppToast.warning('Isi minimal satu jam (masuk atau pulang).');
                    return;
                  }
                  if (reasonC.text.trim().isEmpty) {
                    AppToast.warning('Alasan wajib diisi.');
                    return;
                  }
                  final ok = await controller.submit(
                    date: fmt(date.value!),
                    clockIn: clockIn.value,
                    clockOut: clockOut.value,
                    reason: reasonC.text.trim(),
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
