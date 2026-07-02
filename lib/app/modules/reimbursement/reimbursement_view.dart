import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/ui.dart';
import 'reimbursement_controller.dart';

class ReimbursementView extends GetView<ReimbursementController> {
  const ReimbursementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.muted,
      appBar: AppBar(title: const Text('Reimbursement')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Iconsax.add, color: Colors.white),
        label: const Text('Ajukan', style: TextStyle(color: Colors.white)),
      ),
      body: Obx(() {
        if (controller.isLoading.value) return const Loading();
        if (controller.items.isEmpty) return const EmptyState(icon: Iconsax.wallet_money, message: 'Belum ada reimbursement.');
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView.separated(
            padding: EdgeInsets.all(20.w),
            itemCount: controller.items.length,
            separatorBuilder: (_, i) => SizedBox(height: 10.h),
            itemBuilder: (_, i) {
              final r = controller.items[i];
              return Container(
                padding: EdgeInsets.all(14.w),
                decoration: softCard(radius: 14),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.title ?? r.category, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy, fontSize: 13.5.sp)),
                      Padding(padding: EdgeInsets.only(top: 2.h), child: Text('${r.category} · ${r.date}', style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp))),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(formatRupiah(r.amount), style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 13.sp)),
                    SizedBox(height: 4.h),
                    StatusChip(r.status),
                  ]),
                ]),
              );
            },
          ),
        );
      }),
    );
  }

  void _openSheet(BuildContext context) {
    final categoryC = TextEditingController();
    final amountC = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 20.h, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ajukan Reimbursement', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 16.sp)),
          SizedBox(height: 16.h),
          TextField(controller: categoryC, decoration: const InputDecoration(labelText: 'Kategori (mis. transport, medis)', border: OutlineInputBorder())),
          SizedBox(height: 12.h),
          TextField(controller: amountC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal (Rp)', border: OutlineInputBorder())),
          SizedBox(height: 18.h),
          SizedBox(
            width: double.infinity,
            child: Obx(() => ElevatedButton(
                  onPressed: controller.submitting.value
                      ? null
                      : () async {
                          final amount = int.tryParse(amountC.text.trim().replaceAll(RegExp(r'[^0-9]'), ''));
                          if (categoryC.text.trim().isEmpty || amount == null || amount <= 0) {
                            AppToast.error('Lengkapi kategori & nominal.');
                            return;
                          }
                          final ok = await controller.submit(category: categoryC.text.trim(), amount: amount);
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
