import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_toast.dart';
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
            physics: const AlwaysScrollableScrollPhysics(),
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
                          const IconBubble(Iconsax.sun_1, Color(0xFF16A34A)),
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
              if (controller.requests.isEmpty)
                const EmptyState(
                  icon: Iconsax.sun_1,
                  message: 'Belum ada pengajuan cuti.',
                )
              else
                ...controller.requests.map(
                  (r) => Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: ContentCard(
                      child: Row(
                        children: [
                          const IconBubble(Iconsax.sun_1, Color(0xFF16A34A)),
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
          top: 20.h,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ajukan Cuti',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
                fontSize: 16.sp,
              ),
            ),
            SizedBox(height: 16.h),
            Obx(
              () => DropdownButtonFormField<int>(
                value: controller.types.any((t) => t.id == typeId.value)
                    ? typeId.value
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Jenis Cuti',
                  border: OutlineInputBorder(),
                ),
                items: controller.types
                    .map(
                      (t) => DropdownMenuItem(value: t.id, child: Text(t.name)),
                    )
                    .toList(),
                onChanged: (v) => typeId.value = v ?? 0,
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: Obx(
                    () => _dateField(
                      ctx,
                      'Mulai',
                      start.value,
                      (d) => start.value = d,
                      fmt,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Obx(
                    () => _dateField(
                      ctx,
                      'Selesai',
                      end.value,
                      (d) => end.value = d,
                      fmt,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: reasonC,
              decoration: const InputDecoration(
                labelText: 'Alasan (opsional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 18.h),
            SizedBox(
              width: double.infinity,
              child: Obx(
                () => ElevatedButton(
                  onPressed: controller.submitting.value
                      ? null
                      : () async {
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  child: controller.submitting.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Kirim',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(
    BuildContext ctx,
    String label,
    DateTime? value,
    void Function(DateTime) onPick,
    String Function(DateTime) fmt,
  ) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final d = await showDatePicker(
          context: ctx,
          initialDate: value ?? now,
          firstDate: now.subtract(const Duration(days: 1)),
          lastDate: now.add(const Duration(days: 365)),
        );
        if (d != null) onPick(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(
          value == null ? 'Pilih' : fmt(value),
          style: TextStyle(
            fontSize: 13.sp,
            color: value == null ? AppColors.textMuted : AppColors.navy,
          ),
        ),
      ),
    );
  }
}
