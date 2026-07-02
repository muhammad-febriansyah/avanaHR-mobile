import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_toast.dart';
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
        return RefreshIndicator(
          onRefresh: controller.load,
          color: AppColors.primary,
          child: controller.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: 80.h),
                    const EmptyState(
                      icon: Iconsax.calendar_remove,
                      message: 'Belum ada pengajuan izin.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 90.h),
                  itemCount: controller.items.length,
                  separatorBuilder: (_, i) => SizedBox(height: 10.h),
                  itemBuilder: (_, i) {
                    final p = controller.items[i];
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                  '${p.date}$time',
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
        );
      }),
    );
  }

  void _openSheet(BuildContext context) {
    final date = Rxn<DateTime>();
    final typeC = TextEditingController();
    final start = Rxn<TimeOfDay>();
    final end = Rxn<TimeOfDay>();
    final reasonC = TextEditingController();
    String fmtD(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    String fmtT(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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
              'Ajukan Izin',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
                fontSize: 16.sp,
              ),
            ),
            SizedBox(height: 16.h),
            Obx(
              () => InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: date.value ?? now,
                    firstDate: now.subtract(const Duration(days: 7)),
                    lastDate: now.add(const Duration(days: 60)),
                  );
                  if (d != null) date.value = d;
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    date.value == null ? 'Pilih' : fmtD(date.value!),
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: date.value == null
                          ? AppColors.textMuted
                          : AppColors.navy,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: typeC,
              decoration: const InputDecoration(
                labelText: 'Jenis izin (mis. keluar, sakit)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: Obx(
                    () => _timeField(
                      ctx,
                      'Mulai',
                      start.value,
                      (t) => start.value = t,
                      fmtT,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Obx(
                    () => _timeField(
                      ctx,
                      'Selesai',
                      end.value,
                      (t) => end.value = t,
                      fmtT,
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
                          if (date.value == null || typeC.text.trim().isEmpty) {
                            AppToast.warning('Lengkapi tanggal & jenis izin.');
                            return;
                          }
                          final ok = await controller.submit(
                            date: fmtD(date.value!),
                            type: typeC.text.trim(),
                            startTime: start.value == null
                                ? null
                                : fmtT(start.value!),
                            endTime: end.value == null
                                ? null
                                : fmtT(end.value!),
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

  Widget _timeField(
    BuildContext ctx,
    String label,
    TimeOfDay? v,
    void Function(TimeOfDay) onPick,
    String Function(TimeOfDay) fmt,
  ) => InkWell(
    onTap: () async {
      final t = await showTimePicker(
        context: ctx,
        initialTime: v ?? TimeOfDay.now(),
      );
      if (t != null) onPick(t);
    },
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: Text(
        v == null ? 'Pilih' : fmt(v),
        style: TextStyle(
          fontSize: 13.sp,
          color: v == null ? AppColors.textMuted : AppColors.navy,
        ),
      ),
    ),
  );
}
