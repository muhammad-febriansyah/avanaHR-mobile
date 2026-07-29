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
import 'widgets/token_spend_chart.dart';

final _count = NumberFormat.decimalPattern('id');

/// Buying and tracking AI tokens for yourself.
///
/// What somebody can spend right now is the one thing worth seeing without a
/// scroll, so it is pinned above the tabs. Everything else answers a different
/// question — how fast am I spending, what can I buy, what did I buy — and each
/// gets a tab of its own rather than another screenful below the last.
class AiTokensView extends GetView<AiTokensController> {
  const AiTokensView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: AppPage(
        title: 'Token AI Saya',
        subtitle: 'Jatah perusahaan & token milik Anda',
        actions: [HeaderAction(Iconsax.refresh, controller.load)],
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Loading();
          }

          final balance = controller.balance.value;

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
                child: Column(
                  children: [
                    if (balance != null) _wallet(balance),
                    if (controller.pendingOrder.value != null) ...[
                      SizedBox(height: 12.h),
                      _pendingBanner(),
                    ],
                  ],
                ),
              ),
              _tabs(),
              Expanded(
                child: TabBarView(
                  children: [
                    _usageTab(context),
                    _buyTab(context),
                    _historyTab(context),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── Wallet ────────────────────────────────────────────────────────────────

  /// One headline number, with the two pools that make it up underneath: a
  /// single "sisa 7.000" cannot say whether buying more would help or whether
  /// the reader is only waiting for next month.
  Widget _wallet(AiTokenBalance balance) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18.r),
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
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Iconsax.flash_1,
                  size: 13.sp,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                'Bisa dipakai sekarang',
                style: TextStyle(fontSize: 11.5.sp, color: AppColors.textMuted),
              ),
              const Spacer(),
              Text(
                balance.period,
                style: TextStyle(fontSize: 10.5.sp, color: AppColors.textMuted),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            balance.effectiveRemaining == null
                ? 'Tanpa batas'
                : _count.format(balance.effectiveRemaining),
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.6,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _pool(
                  icon: Iconsax.buildings_2,
                  tone: AppColors.primary,
                  label: 'Jatah perusahaan',
                  value: balance.companyRemaining == null
                      ? 'Tanpa batas'
                      : _count.format(balance.companyRemaining),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _pool(
                  icon: Iconsax.wallet_3,
                  tone: AppColors.success,
                  label: 'Token pribadi',
                  value: _count.format(balance.personalBalance),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pool({
    required IconData icon,
    required Color tone,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14.sp, color: tone),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shown while an order is waiting at the payment page.
  Widget _pendingBanner() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(Iconsax.clock, size: 16.sp, color: AppColors.warning),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Menunggu pembayaran. Token masuk otomatis setelah lunas.',
              style: TextStyle(
                fontSize: 11.5.sp,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
          GestureDetector(
            onTap: controller.checkPending,
            child: Text(
              'Cek',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tabs ──────────────────────────────────────────────────────────────────

  Widget _tabs() {
    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 4.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: TabBar(
        indicator: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(9.r),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(9.r),
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
        ),
        tabs: [
          Tab(height: 34.h, text: 'Pemakaian'),
          Tab(height: 34.h, text: 'Beli'),
          Tab(height: 34.h, text: 'Riwayat'),
        ],
      ),
    );
  }

  EdgeInsets _tabPadding(BuildContext context) => EdgeInsets.fromLTRB(
    20.w,
    14.h,
    20.w,
    24.h + AppPage.bottomNavClearance(context),
  );

  // ── Pemakaian ─────────────────────────────────────────────────────────────

  Widget _usageTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.load,
      color: AppColors.primary,
      child: Obx(() {
        final spend = controller.spend.value;
        final monthly = controller.chartIsMonthly.value;

        return ListView(
          padding: _tabPadding(context),
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Token terpakai',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      _rangeToggle(monthly),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  if (spend == null)
                    const EmptyState(
                      icon: Iconsax.chart_2,
                      message: 'Data pemakaian belum tersedia.',
                    )
                  else
                    TokenSpendChart(
                      points: monthly ? spend.monthly : spend.daily,
                      monthly: monthly,
                    ),
                ],
              ),
            ),
            if (spend != null) ...[
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: _stat('Hari ini', spend.today),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _stat('7 hari', spend.week),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _stat('Bulan ini', spend.month),
                  ),
                ],
              ),
              if (spend.isEmpty) ...[
                SizedBox(height: 12.h),
                Text(
                  'Belum ada pemakaian yang tercatat. Angka mulai muncul '
                  'setelah Anda memakai AI Assistant.',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: AppColors.textMuted,
                    height: 1.55,
                  ),
                ),
              ],
            ],
            SizedBox(height: 18.h),
            _note(),
          ],
        );
      }),
    );
  }

  /// Days or months. Two buttons rather than a dropdown: there are only two.
  Widget _rangeToggle(bool monthly) {
    Widget option(String label, bool value) {
      final active = monthly == value;

      return GestureDetector(
        onTap: () => controller.chartIsMonthly.value = value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppColors.textMuted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [option('Harian', false), option('Bulanan', true)],
      ),
    );
  }

  Widget _stat(String label, int tokens) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10.5.sp, color: AppColors.textMuted),
          ),
          SizedBox(height: 4.h),
          Text(
            _count.format(tokens),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
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
        Icon(Iconsax.info_circle, size: 14.sp, color: AppColors.textMuted),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            'Token pribadi Anda dipakai lebih dulu; jatah perusahaan baru '
            'dipakai setelah token pribadi habis. Token pribadi tidak dibatasi '
            'jatah bulanan dari admin dan tidak hangus tiap bulan.',
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.textMuted,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }

  // ── Beli ──────────────────────────────────────────────────────────────────

  Widget _buyTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.load,
      color: AppColors.primary,
      child: Obx(
        () => controller.packs.isEmpty
            ? ListView(
                padding: _tabPadding(context),
                children: const [
                  EmptyState(
                    icon: Iconsax.box,
                    message: 'Belum ada paket token yang dijual.',
                  ),
                ],
              )
            : ListView(
                padding: _tabPadding(context),
                children: controller.packs.map(_packCard).toList(),
              ),
      ),
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

  // ── Riwayat ───────────────────────────────────────────────────────────────

  Widget _historyTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.load,
      color: AppColors.primary,
      child: Obx(
        () => controller.orders.isEmpty
            ? ListView(
                padding: _tabPadding(context),
                children: const [
                  EmptyState(
                    icon: Iconsax.receipt_1,
                    message: 'Belum ada pembelian token.',
                  ),
                ],
              )
            : ListView(
                padding: _tabPadding(context),
                children: controller.orders.map(_orderRow).toList(),
              ),
      ),
    );
  }

  Widget _orderRow(AiTokenOrder order) {
    final (label, tone) = switch (order.status) {
      'completed' => ('Lunas', AppColors.success),
      'failed' => ('Gagal', AppColors.danger),
      _ => ('Menunggu', AppColors.warning),
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
                if (order.createdAt != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    formatTanggalJam(order.createdAt),
                    style: TextStyle(fontSize: 10.5.sp, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w600,
                color: tone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
