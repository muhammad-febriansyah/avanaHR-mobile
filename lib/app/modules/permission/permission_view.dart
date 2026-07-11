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
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  children: [
                    SizedBox(height: 80.h),
                    const EmptyState(
                      icon: Iconsax.calendar_remove,
                      message: 'Belum ada pengajuan izin.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
    final start = RxnString();
    final end = RxnString();
    final reasonC = TextEditingController();
    String fmtD(DateTime d) =>
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
            const SheetHeader('Ajukan Izin'),
            SizedBox(height: 18.h),
            Obx(
              () => AppDateField(
                label: 'Tanggal',
                value: date.value,
                onPick: (d) => date.value = d,
                required: true,
              ),
            ),
            SizedBox(height: 14.h),
            AppTextField(
              controller: typeC,
              label: 'Jenis Izin',
              hint: 'mis. keluar kantor',
              required: true,
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: Obx(
                    () => AppTimeField(
                      label: 'Jam Mulai',
                      value: start.value,
                      onPick: (t) => start.value = t,
                      required: true,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Obx(
                    () => AppTimeField(
                      label: 'Jam Selesai',
                      value: end.value,
                      onPick: (t) => end.value = t,
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
                  if (date.value == null || typeC.text.trim().isEmpty) {
                    AppToast.warning('Lengkapi tanggal & jenis izin.');
                    return;
                  }
                  final ok = await controller.submit(
                    date: fmtD(date.value!),
                    type: typeC.text.trim(),
                    startTime: start.value,
                    endTime: end.value,
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
