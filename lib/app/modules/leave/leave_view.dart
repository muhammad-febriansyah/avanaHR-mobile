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
import 'leave_controller.dart';

class LeaveView extends GetView<LeaveController> {
  const LeaveView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Cuti',
      subtitle: 'Saldo & pengajuan',
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
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 90.h),
            children: [
              const SectionTitle('Saldo Cuti'),
              SizedBox(height: 12.h),
              if (controller.balances.isEmpty)
                const EmptyState(
                  icon: Iconsax.sun_1,
                  message: 'Belum ada data saldo.',
                )
              else
                ...controller.balances.map(
                  (b) => Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: ContentCard(
                      child: Row(
                        children: [
                          const IconBubble(Iconsax.sun_1, Color(0xFF22C55E)),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              b.leaveType ?? '-',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.navy,
                                fontSize: 13.5.sp,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            '${b.available.toInt()}/${b.entitled.toInt()} hari',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              SizedBox(height: 18.h),
              const SectionTitle('Riwayat Pengajuan'),
              SizedBox(height: 12.h),
              FilterChips(
                options: kStatusFilterOptions,
                selected: controller.statusFilter.value,
                onSelected: (v) => controller.statusFilter.value = v,
              ),
              SizedBox(height: 12.h),
              if (controller.visibleRequests.isEmpty)
                const EmptyState(
                  icon: Iconsax.sun_1,
                  message: 'Belum ada pengajuan cuti.',
                )
              else
                ...controller.visibleRequests.map(
                  (r) => Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: ContentCard(
                      child: Row(
                        children: [
                          const IconBubble(Iconsax.sun_1, Color(0xFF22C55E)),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.leaveType ?? 'Cuti',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                    fontSize: 13.5.sp,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  '${r.startDate} → ${r.endDate} · ${r.totalDays} hari',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          StatusChip(r.status),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  void _openSheet(BuildContext context) {
    final typeId =
        (controller.types.isNotEmpty ? controller.types.first.id : 0).obs;
    final start = Rxn<DateTime>();
    final end = Rxn<DateTime>();
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
            const SheetHeader('Ajukan Cuti'),
            SizedBox(height: 18.h),
            Obx(
              () => AppDropdownField<int>(
                label: 'Jenis Cuti',
                hint: 'Pilih jenis cuti',
                value: controller.types.any((t) => t.id == typeId.value)
                    ? typeId.value
                    : null,
                items: controller.types
                    .map(
                      (t) => DropdownMenuItem(value: t.id, child: Text(t.name)),
                    )
                    .toList(),
                onChanged: (v) => typeId.value = v ?? 0,
                required: true,
              ),
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: Obx(
                    () => AppDateField(
                      label: 'Mulai',
                      value: start.value,
                      onPick: (d) => start.value = d,
                      required: true,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Obx(
                    () => AppDateField(
                      label: 'Selesai',
                      value: end.value,
                      onPick: (d) => end.value = d,
                      required: true,
                    ),
                  ),
                ),
              ],
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
                  if (typeId.value == 0 ||
                      start.value == null ||
                      end.value == null) {
                    AppToast.warning('Lengkapi jenis cuti & tanggal.');
                    return;
                  }
                  final ok = await controller.submit(
                    leaveTypeId: typeId.value,
                    startDate: fmt(start.value!),
                    endDate: fmt(end.value!),
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
