import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/ui.dart';
import 'wfh_controller.dart';

class WfhView extends GetView<WfhController> {
  const WfhView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.muted,
      appBar: AppBar(title: const Text('Kerja dari Rumah')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Iconsax.add, color: Colors.white),
        label: const Text('Ajukan', style: TextStyle(color: Colors.white)),
      ),
      body: Obx(() {
        if (controller.isLoading.value) return const Loading();
        if (controller.items.isEmpty) return const EmptyState(icon: Iconsax.house, message: 'Belum ada pengajuan WFH.');
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView.separated(
            padding: EdgeInsets.all(20.w),
            itemCount: controller.items.length,
            separatorBuilder: (_, i) => SizedBox(height: 10.h),
            itemBuilder: (_, i) {
              final w = controller.items[i];
              return Container(
                padding: EdgeInsets.all(14.w),
                decoration: softCard(radius: 14),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${w.startDate} → ${w.endDate}', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy, fontSize: 13.5.sp)),
                      if (w.reason != null && w.reason!.isNotEmpty) Padding(padding: EdgeInsets.only(top: 2.h), child: Text(w.reason!, style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp))),
                    ]),
                  ),
                  StatusChip(w.status),
                ]),
              );
            },
          ),
        );
      }),
    );
  }

  void _openSheet(BuildContext context) {
    final start = Rxn<DateTime>();
    final end = Rxn<DateTime>();
    final reasonC = TextEditingController();
    String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    Widget dateField(BuildContext ctx, String label, DateTime? v, void Function(DateTime) onPick) => InkWell(
          onTap: () async {
            final now = DateTime.now();
            final d = await showDatePicker(context: ctx, initialDate: v ?? now, firstDate: now, lastDate: now.add(const Duration(days: 180)));
            if (d != null) onPick(d);
          },
          child: InputDecorator(
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
            child: Text(v == null ? 'Pilih' : fmt(v), style: TextStyle(fontSize: 13.sp, color: v == null ? AppColors.textMuted : AppColors.navy)),
          ),
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 20.h, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ajukan WFH', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 16.sp)),
          SizedBox(height: 16.h),
          Row(children: [
            Expanded(child: Obx(() => dateField(ctx, 'Mulai', start.value, (d) => start.value = d))),
            SizedBox(width: 12.w),
            Expanded(child: Obx(() => dateField(ctx, 'Selesai', end.value, (d) => end.value = d))),
          ]),
          SizedBox(height: 12.h),
          TextField(controller: reasonC, decoration: const InputDecoration(labelText: 'Alasan (opsional)', border: OutlineInputBorder()), maxLines: 2),
          SizedBox(height: 18.h),
          SizedBox(
            width: double.infinity,
            child: Obx(() => ElevatedButton(
                  onPressed: controller.submitting.value
                      ? null
                      : () async {
                          if (start.value == null || end.value == null) {
                            AppToast.warning('Lengkapi tanggal.');
                            return;
                          }
                          final ok = await controller.submit(startDate: fmt(start.value!), endDate: fmt(end.value!), reason: reasonC.text.trim().isEmpty ? null : reasonC.text.trim());
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
