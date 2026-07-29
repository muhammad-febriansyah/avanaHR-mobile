import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/ai_models.dart';
import 'ai_tokens_controller.dart';

final _count = NumberFormat.decimalPattern('id');

/// Buying AI tokens for yourself.
///
/// The company's allowance and the personal wallet are shown apart before they
/// are shown together: a single "sisa 7.000" cannot tell somebody whether
/// buying more would help, or whether they are only waiting for next month.
class AiTokensView extends GetView<AiTokensController> {
  const AiTokensView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Token AI Saya',
      subtitle: 'Jatah perusahaan & token milik Anda',
      onRefresh: controller.load,
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Loading();
        }

        final balance = controller.balance.value;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            20.w,
            8.h,
            20.w,
            24.h + AppPage.bottomNavClearance(context),
          ),
          children: [
            if (balance != null) _balances(balance),
            SizedBox(height: 18.h),
            if (controller.pendingOrder.value != null) ...[
              _pendingBanner(),
              SizedBox(height: 18.h),
            ],
            _note(),
            SizedBox(height: 22.h),
            SectionTitle('Beli token'),
            SizedBox(height: 12.h),
            if (controller.packs.isEmpty)
              const EmptyState(
                icon: Iconsax.box,
                message: 'Belum ada paket token yang dijual.',
              )
            else
              ...controller.packs.map(_packCard),
            if (controller.orders.isNotEmpty) ...[
              SizedBox(height: 22.h),
              SectionTitle('Riwayat pembelian'),
              SizedBox(height: 12.h),
              ...controller.orders.map(_orderRow),
            ],
          ],
        );
      }),
    );
  }

  Widget _balances(AiTokenBalance balance) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _balanceCard(
                icon: Iconsax.buildings_2,
                tone: AppColors.primary,
                label: 'Jatah perusahaan',
                value: balance.companyRemaining == null
                    ? 'Tanpa batas'
                    : _count.format(balance.companyRemaining),
                note: balance.userCap == null
                    ? 'Terpakai ${_count.format(balance.userUsed)}'
                    : 'Terpakai ${_count.format(balance.userUsed)} / ${_count.format(balance.userCap)}',
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _balanceCard(
                icon: Iconsax.wallet_3,
                tone: AppColors.success,
                label: 'Token pribadi',
                value: _count.format(balance.personalBalance),
                note: 'Tidak hangus tiap bulan',
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        _balanceCard(
          icon: Iconsax.flash_1,
          tone: AppColors.textPrimary,
          label: 'Bisa dipakai sekarang',
          value: balance.effectiveRemaining == null
              ? 'Tanpa batas'
              : _count.format(balance.effectiveRemaining),
          note: 'Token pribadi dipakai lebih dulu · ${balance.period}',
          wide: true,
        ),
      ],
    );
  }

  Widget _balanceCard({
    required IconData icon,
    required Color tone,
    required String label,
    required String value,
    required String note,
    bool wide = false,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, size: 14.sp, color: tone),
              ),
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            value,
            style: TextStyle(
              fontSize: wide ? 24.sp : 20.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            note,
            style: TextStyle(fontSize: 10.5.sp, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  /// Shown while an order is waiting at the payment page.
  Widget _pendingBanner() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(Iconsax.clock, size: 18.sp, color: AppColors.primary),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Menunggu pembayaran. Token masuk otomatis setelah lunas.',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
          ),
          TextButton(
            onPressed: controller.checkPending,
            child: Text(
              'Cek',
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _note() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Iconsax.info_circle, size: 15.sp, color: AppColors.textMuted),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            'Token pribadi Anda dipakai lebih dulu; jatah perusahaan baru '
            'dipakai setelah token pribadi habis. Token pribadi tidak dibatasi '
            'jatah bulanan dari admin dan tidak hangus tiap bulan.',
            style: TextStyle(
              fontSize: 11.5.sp,
              color: AppColors.textMuted,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }

  Widget _packCard(AiTokenPack pack) {
    return Obx(() {
      final busy = controller.buyingPackId.value != null;
      final thisOne = controller.buyingPackId.value == pack.id;

      return Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pack.name,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _count.format(pack.tokenAmount),
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 5.w),
                Text(
                  'token',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            if (pack.description != null && pack.description!.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(
                pack.description!,
                style: TextStyle(
                  fontSize: 11.5.sp,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
            SizedBox(height: 14.h),
            SizedBox(
              width: double.infinity,
              height: 44.h,
              child: ElevatedButton(
                onPressed: busy ? null : () => controller.buy(pack),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.5,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  thisOne ? 'Menyiapkan…' : 'Beli ${formatRupiah(pack.price)}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _orderRow(AiTokenOrder order) {
    final (label, tone) = switch (order.status) {
      'completed' => ('Lunas', AppColors.success),
      'failed' => ('Gagal', Colors.red),
      _ => ('Menunggu', AppColors.textMuted),
    };

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.packName,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${_count.format(order.tokenAmount)} token · ${formatRupiah(order.amount)}',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w600,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}
