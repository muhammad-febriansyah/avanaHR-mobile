import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/ui.dart';
import 'payslip_controller.dart';

class PayslipView extends GetView<PayslipController> {
  const PayslipView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.muted,
      appBar: AppBar(title: const Text('Slip Gaji')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Loading();
        }
        if (controller.items.isEmpty) {
          return const EmptyState(icon: Iconsax.receipt_2, message: 'Belum ada slip gaji.');
        }
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600),
            child: RefreshIndicator(
              onRefresh: controller.load,
              child: ListView.separated(
                padding: EdgeInsets.all(20.w),
                itemCount: controller.items.length,
                separatorBuilder: (_, i) => SizedBox(height: 12.h),
                itemBuilder: (_, i) {
                  final p = controller.items[i];
                  return Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: softCard(radius: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(Iconsax.receipt_2, color: AppColors.primary, size: 24.sp),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.period ?? monthLabel(p.periodMonth, p.periodYear),
                                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 14.sp),
                              ),
                              Text('Diterbitkan ${p.issuedAt ?? '-'}', style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Netto', style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp)),
                            Text(
                              formatRupiah(p.net),
                              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success, fontSize: 14.sp),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }),
    );
  }
}
