import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/filter_chips.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/ess_models.dart';
import '../../routes/app_pages.dart';
import 'settlement_controller.dart';
import 'widgets/settlement_status_chip.dart';

const _filters = <FilterOption>[
  FilterOption('all', 'Semua'),
  FilterOption('pending', 'Diproses'),
  FilterOption('paid', 'Dibayar'),
  FilterOption('rejected', 'Ditolak'),
];

/// Lists the employee's settlement claims, newest first.
class SettlementView extends GetView<SettlementController> {
  const SettlementView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Settlement',
      subtitle: 'Klaim biaya perjalanan dinas',
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Loading();
        }

        return Column(
          children: [
            if (controller.items.isNotEmpty) _PaidTotal(controller.paidTotal),
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
                            icon: Iconsax.receipt_2_1,
                            message: 'Belum ada settlement.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          20.w,
                          16.h,
                          20.w,
                          AppPage.bottomNavClearance(context),
                        ),
                        itemCount: controller.visibleItems.length,
                        separatorBuilder: (_, _) => SizedBox(height: 10.h),
                        itemBuilder: (_, i) =>
                            _SettlementRow(controller.visibleItems[i]),
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Sum of everything already disbursed, above the list.
class _PaidTotal extends StatelessWidget {
  final int amount;

  const _PaidTotal(this.amount);

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
          Icon(Iconsax.wallet_check, color: Colors.white, size: 20.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL DIBAYAR',
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

/// One settlement row, tapping through to the detail screen.
class _SettlementRow extends StatelessWidget {
  final SettlementItem item;

  const _SettlementRow(this.item);

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      onTap: () => Get.toNamed(Routes.SETTLEMENT_DETAIL, arguments: item.id),
      child: Row(
        children: [
          const IconBubble(Iconsax.receipt_2_1, Color(0xFF2563EB)),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
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
                  [
                    item.number,
                    if (item.destination != null) item.destination,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  formatRupiah(item.total),
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
          SettlementStatusChip(item.status),
        ],
      ),
    );
  }
}
