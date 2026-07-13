import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/ui.dart';
import 'reimbursement_controller.dart';

class ReimbursementView extends GetView<ReimbursementController> {
  const ReimbursementView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Reimbursement',
      subtitle: 'Ajukan & pantau klaim',
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
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    SizedBox(height: 80.h),
                    const EmptyState(
                      icon: Iconsax.wallet_money,
                      message: 'Belum ada reimbursement.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 90.h),
                  itemCount: controller.items.length,
                  separatorBuilder: (_, i) => SizedBox(height: 10.h),
                  itemBuilder: (_, i) {
                    final r = controller.items[i];
                    return ContentCard(
                      child: Row(
                        children: [
                          const IconBubble(
                            Iconsax.wallet_money,
                            Color(0xFFDB2777),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.title ?? r.category,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                    fontSize: 13.5.sp,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  '${formatRupiah(r.amount)} · ${r.date}',
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
    final receiptPath = RxnString();

    showAppSheet(
      context,
      scrollable: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHeader('Ajukan Reimbursement'),
              SizedBox(height: 18.h),
              AppTextField(
                controller: categoryC,
                label: 'Kategori',
                hint: 'mis. transport, medis',
                icon: Iconsax.category,
                required: true,
              ),
              SizedBox(height: 14.h),
              AppTextField(
                controller: amountC,
                label: 'Nominal',
                hint: '0',
                prefixText: 'Rp ',
                keyboardType: TextInputType.number,
                formatters: [RupiahInputFormatter()],
                required: true,
              ),
              SizedBox(height: 14.h),
              Obx(
                () => AppImageField(
                  label: 'Struk / Bukti (opsional)',
                  hint: 'Foto struk — kamera atau galeri',
                  path: receiptPath.value,
                  onPick: (p) => receiptPath.value = p,
                  onClear: () => receiptPath.value = null,
                ),
              ),
              SizedBox(height: 22.h),
              Obx(
                () => AppSubmitButton(
                  loading: controller.submitting.value,
                  icon: Iconsax.send_2,
                  label: 'Ajukan',
                  onPressed: () async {
                    final amount = parseRupiah(amountC.text);
                    if (categoryC.text.trim().isEmpty || amount <= 0) {
                      AppToast.warning('Lengkapi kategori & nominal.');
                      return;
                    }
                    final ok = await controller.submit(
                      category: categoryC.text.trim(),
                      amount: amount,
                      receiptPath: receiptPath.value,
                    );
                    if (ok) Get.back();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
