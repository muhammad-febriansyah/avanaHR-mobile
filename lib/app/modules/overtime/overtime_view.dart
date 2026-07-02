import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/ui.dart';
import 'overtime_controller.dart';

class OvertimeView extends GetView<OvertimeController> {
  const OvertimeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.muted,
      appBar: AppBar(title: const Text('Lembur')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Iconsax.add, color: Colors.white),
        label: const Text('Ajukan', style: TextStyle(color: Colors.white)),
      ),
      body: Obx(() {
        if (controller.isLoading.value) return const Loading();
        if (controller.items.isEmpty) return const EmptyState(icon: Iconsax.timer_1, message: 'Belum ada pengajuan lembur.');
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView.separated(
            padding: EdgeInsets.all(20.w),
            itemCount: controller.items.length,
            separatorBuilder: (_, i) => SizedBox(height: 10.h),
            itemBuilder: (_, i) {
              final o = controller.items[i];
              return Container(
                padding: EdgeInsets.all(14.w),
                decoration: softCard(radius: 14),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${o.hours} jam · ${o.date}', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy, fontSize: 13.5.sp)),
                      if (o.reason != null && o.reason!.isNotEmpty) Padding(padding: EdgeInsets.only(top: 2.h), child: Text(o.reason!, style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp))),
                    ]),
                  ),
                  StatusChip(o.status),
                ]),
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
    String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 20.h, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ajukan Lembur', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 16.sp)),
          SizedBox(height: 16.h),
          Obx(() => InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(context: ctx, initialDate: date.value ?? now, firstDate: now.subtract(const Duration(days: 30)), lastDate: now.add(const Duration(days: 30)));
                  if (d != null) date.value = d;
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Tanggal', border: OutlineInputBorder()),
                  child: Text(date.value == null ? 'Pilih' : fmt(date.value!), style: TextStyle(fontSize: 13.sp, color: date.value == null ? AppColors.textMuted : AppColors.navy)),
                ),
              )),
          SizedBox(height: 12.h),
          TextField(controller: hoursC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Jumlah jam', border: OutlineInputBorder())),
          SizedBox(height: 12.h),
          TextField(controller: reasonC, decoration: const InputDecoration(labelText: 'Alasan (opsional)', border: OutlineInputBorder()), maxLines: 2),
          SizedBox(height: 18.h),
          SizedBox(
            width: double.infinity,
            child: Obx(() => ElevatedButton(
                  onPressed: controller.submitting.value
                      ? null
                      : () async {
                          final hours = double.tryParse(hoursC.text.trim());
                          if (date.value == null || hours == null || hours <= 0) {
                            AppToast.warning('Lengkapi tanggal & jam.');
                            return;
                          }
                          final ok = await controller.submit(date: fmt(date.value!), hours: hours, reason: reasonC.text.trim().isEmpty ? null : reasonC.text.trim());
                          if (ok) Get.back();
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: EdgeInsets.symmetric(vertical: 14.h)),
                  child: controller.submitting.value
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Kirim', style: TextStyle(color: Colors.white)),
                )),
          ),
        ]),
      ),
    );
  }
}
