import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/payslip.dart';
import 'payslip_controller.dart';

class PayslipView extends GetView<PayslipController> {
  const PayslipView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Slip Gaji',
      subtitle: 'Riwayat gaji',
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
                      icon: Iconsax.receipt_2,
                      message: 'Belum ada slip gaji.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
                  itemCount: controller.items.length,
                  separatorBuilder: (_, i) => SizedBox(height: 10.h),
                  itemBuilder: (_, i) {
                    final p = controller.items[i];
                    return ContentCard(
                      onTap: () => _openActions(context, p),
                      child: Row(
                        children: [
                          const IconBubble(
                            Iconsax.receipt_2,
                            Color(0xFF0891B2),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.period ??
                                      monthLabel(p.periodMonth, p.periodYear),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                    fontSize: 13.5.sp,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  formatRupiah(p.net),
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Icon(
                            Iconsax.document_download,
                            size: 20.sp,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      }),
    );
  }

  void _openActions(BuildContext context, Payslip p) {
    showAppSheet(
      context,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 28.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.period ?? monthLabel(p.periodMonth, p.periodYear),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Gaji bersih ${formatRupiah(p.net)}',
              style: TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted),
            ),
            SizedBox(height: 18.h),
            Row(
              children: [
                Expanded(
                  child: _pdfButton(
                    'Buka',
                    Iconsax.document_text,
                    false,
                    () async {
                      Get.back();
                      await controller.openPdf(p.id);
                    },
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _pdfButton('Bagikan', Iconsax.share, true, () async {
                    Get.back();
                    await controller.sharePdf(p.id);
                  }),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                Icon(Iconsax.lock_1, size: 14.sp, color: AppColors.textMuted),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    'PDF terproteksi. Password: tanggal lahir Anda (hhbbtttt).',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pdfButton(
    String label,
    IconData icon,
    bool filled,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: filled
              ? null
              : Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18.sp,
              color: filled ? Colors.white : AppColors.primary,
            ),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w700,
                color: filled ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
