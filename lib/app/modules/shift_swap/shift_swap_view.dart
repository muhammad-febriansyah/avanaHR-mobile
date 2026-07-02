import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/ui.dart';
import 'shift_swap_controller.dart';

class ShiftSwapView extends GetView<ShiftSwapController> {
  const ShiftSwapView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Tukar Shift',
      subtitle: 'Ajukan & pantau tukar shift',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Iconsax.arrow_swap_horizontal, color: Colors.white),
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
                      icon: Iconsax.arrow_swap_horizontal,
                      message: 'Belum ada pengajuan tukar shift.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 90.h),
                  itemCount: controller.items.length,
                  separatorBuilder: (_, i) => SizedBox(height: 10.h),
                  itemBuilder: (_, i) {
                    final s = controller.items[i];
                    final isOutgoing = s.direction == 'outgoing';
                    final title = isOutgoing
                        ? 'Ke ${s.target ?? '-'}'
                        : 'Dari ${s.requester ?? '-'}';
                    return ContentCard(
                      child: Row(
                        children: [
                          const IconBubble(
                            Iconsax.arrow_swap_horizontal,
                            Color(0xFF0D9488),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                    fontSize: 13.5.sp,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  s.date,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12.sp,
                                  ),
                                ),
                                if (s.reason != null && s.reason!.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(top: 2.h),
                                    child: Text(
                                      s.reason!,
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
                          StatusChip(s.status),
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
    if (controller.colleagues.isEmpty) {
      AppToast.warning('Belum ada rekan untuk tukar shift.');
      return;
    }
    final target = Rxn<int>();
    final date = Rxn<DateTime>();
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
              'Ajukan Tukar Shift',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
                fontSize: 16.sp,
              ),
            ),
            SizedBox(height: 16.h),
            Obx(
              () => DropdownButtonFormField<int>(
                initialValue: target.value,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Rekan',
                  border: OutlineInputBorder(),
                ),
                items: controller.colleagues
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          c.employeeNumber == null
                              ? c.name
                              : '${c.name} (${c.employeeNumber})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => target.value = v,
              ),
            ),
            SizedBox(height: 12.h),
            Obx(
              () => InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: date.value ?? now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 60)),
                  );
                  if (d != null) date.value = d;
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal shift',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    date.value == null ? 'Pilih' : fmt(date.value!),
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
                          if (target.value == null || date.value == null) {
                            AppToast.warning('Pilih rekan & tanggal.');
                            return;
                          }
                          final ok = await controller.submit(
                            targetId: target.value!,
                            date: fmt(date.value!),
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
}
