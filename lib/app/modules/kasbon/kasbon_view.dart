import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/filter_chips.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/ess_models.dart';
import '../../routes/app_pages.dart';
import 'kasbon_controller.dart';
import 'widgets/kasbon_status_chip.dart';

const _filters = <FilterOption>[
  FilterOption('all', 'Semua'),
  FilterOption('pending', 'Diproses'),
  FilterOption('disbursed', 'Dicairkan'),
  FilterOption('rejected', 'Ditolak'),
];

/// The employee's cash advances (uang muka): money asked for before spending.
class KasbonView extends GetView<KasbonController> {
  const KasbonView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Uang Muka',
      subtitle: 'Ajukan & pantau kasbon',
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

        return Column(
          children: [
            if (controller.items.isNotEmpty)
              _DisbursedTotal(controller.disbursedTotal),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 4.h),
              child: FilterChips(
                options: _filters,
                selected: controller.statusFilter.value,
                onSelected: (v) => controller.statusFilter.value = v,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.load,
                color: AppColors.primary,
                child: controller.visibleItems.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        children: [
                          SizedBox(height: 80.h),
                          const EmptyState(
                            icon: Iconsax.wallet_add,
                            message: 'Belum ada pengajuan uang muka.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 90.h),
                        itemCount: controller.visibleItems.length,
                        separatorBuilder: (_, _) => SizedBox(height: 10.h),
                        itemBuilder: (_, i) =>
                            _AdvanceRow(controller.visibleItems[i]),
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }

  /// The "ajukan uang muka" form.
  void _openSheet(BuildContext context) {
    final needed = Rxn<DateTime>(DateTime.now().add(const Duration(days: 7)));
    final amountC = TextEditingController();
    final purposeC = TextEditingController();
    final reasonC = TextEditingController();

    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
              const SheetHeader('Ajukan Uang Muka'),
              SizedBox(height: 18.h),
              AppMoneyField(
                controller: amountC,
                label: 'Jumlah',
                hint: '2000000',
                required: true,
              ),
              SizedBox(height: 14.h),
              AppTextField(
                controller: purposeC,
                label: 'Keperluan',
                hint: 'Uang muka dinas Bandung 3 hari',
                icon: Iconsax.note_1,
                required: true,
              ),
              SizedBox(height: 14.h),
              Obx(
                () => AppDateField(
                  label: 'Dibutuhkan Tanggal',
                  value: needed.value,
                  onPick: (d) => needed.value = d,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  required: true,
                ),
              ),
              SizedBox(height: 14.h),
              AppTextField(
                controller: reasonC,
                label: 'Alasan (opsional)',
                hint: 'Kenapa perlu dibayar di muka…',
                icon: Iconsax.note_1,
                maxLines: 2,
              ),
              SizedBox(height: 22.h),
              Obx(
                () => AppSubmitButton(
                  label: 'Ajukan',
                  loading: controller.submitting.value,
                  onPressed: () async {
                    final amount =
                        int.tryParse(
                          amountC.text.replaceAll(RegExp(r'[^0-9]'), ''),
                        ) ??
                        0;

                    if (amount <= 0 ||
                        purposeC.text.trim().isEmpty ||
                        needed.value == null) {
                      AppToast.warning('Isi jumlah, keperluan & tanggal.');
                      return;
                    }

                    final ok = await controller.submit(
                      amount: amount,
                      purpose: purposeC.text.trim(),
                      neededDate: fmt(needed.value!),
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
      ),
    );
  }
}

/// Money already handed over, above the list.
class _DisbursedTotal extends StatelessWidget {
  final int amount;

  const _DisbursedTotal(this.amount);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Icon(Iconsax.wallet_money, color: Colors.white, size: 20.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL DICAIRKAN',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .6,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  formatRupiah(amount),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One advance row, tapping through to the detail screen.
class _AdvanceRow extends StatelessWidget {
  final CashAdvanceItem item;

  const _AdvanceRow(this.item);

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      onTap: () => Get.toNamed(Routes.KASBON_DETAIL, arguments: item.id),
      child: Row(
        children: [
          const IconBubble(Iconsax.wallet_add, Color(0xFF7C3AED)),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.purpose,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  'Dibutuhkan ${item.neededDate}',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  formatRupiah(item.amount),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          KasbonStatusChip(item.status, label: item.statusLabel),
        ],
      ),
    );
  }
}
