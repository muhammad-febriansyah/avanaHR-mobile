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

/// What an empty list means depends on which filter is on — "belum ada
/// settlement" is wrong when the employee simply has nothing rejected.
const _emptyMessages = <String, String>{
  'all': 'Belum ada settlement.',
  'pending': 'Tidak ada settlement yang sedang diproses.',
  'paid': 'Belum ada settlement yang dibayar.',
  'rejected': 'Tidak ada settlement yang ditolak.',
};

/// Lists the employee's settlement claims, newest first.
class SettlementView extends GetView<SettlementController> {
  const SettlementView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Settlement',
      subtitle: 'Klaim biaya perjalanan dinas',
      // Tinted canvas so the white cards read as distinct surfaces — on
      // AppPage's plain white body they dissolve into the background. Matches
      // the detail screen.
      child: ColoredBox(
        color: AppColors.background,
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Loading();
          }

          final selected = controller.statusFilter.value;

          return Column(
            children: [
              if (controller.items.isNotEmpty)
                _SummaryCard(
                  paid: controller.paidTotal,
                  pending: controller.pendingTotal,
                  claims: controller.items.length,
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 6.h),
                child: FilterChips(
                  options: [
                    for (final f in _filters)
                      FilterOption(
                        f.value,
                        // The counter turns the filter row into a summary of
                        // its own — you see there is nothing rejected without
                        // having to tap through.
                        '${f.label} (${controller.countFor(f.value)})',
                      ),
                  ],
                  selected: selected,
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
                            SizedBox(height: 60.h),
                            EmptyState(
                              icon: Iconsax.receipt_2_1,
                              message:
                                  _emptyMessages[selected] ??
                                  'Belum ada settlement.',
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            16.w,
                            10.h,
                            16.w,
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
      ),
    );
  }
}

/// Money already disbursed next to money still on a review desk, on the brand
/// gradient so the list header carries the same weight as the detail hero.
class _SummaryCard extends StatelessWidget {
  final int paid;
  final int pending;
  final int claims;

  const _SummaryCard({
    required this.paid,
    required this.pending,
    required this.claims,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryHover],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: const BrandMeshPainter()),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Iconsax.wallet_check,
                      color: Colors.white.withValues(alpha: 0.72),
                      size: 15.sp,
                    ),
                    SizedBox(width: 7.w),
                    Expanded(
                      child: Text(
                        'TOTAL DIBAYAR',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                    Text(
                      '$claims klaim',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  formatRupiah(paid),
                  style: TextStyle(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -.8,
                    height: 1.1,
                  ),
                ),
                if (pending > 0) ...[
                  SizedBox(height: 12.h),
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Icon(
                        Iconsax.clock,
                        size: 13.sp,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          'Sedang diproses',
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      Text(
                        formatRupiah(pending),
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One settlement row, tapping through to the detail screen.
///
/// Shaped like the thing it represents: a receipt, torn across a perforated
/// line with the total on the stub below it. The claim's identity (number,
/// title, where and when) sits above the tear; the money sits below it, which
/// is the split people actually scan a claim list for.
class _SettlementRow extends StatelessWidget {
  final SettlementItem item;

  const _SettlementRow(this.item);

  @override
  Widget build(BuildContext context) {
    final accent = SettlementStatusChip.colorFor(item.status);
    final paidAt = item.paidAt;
    final isRejected = item.status.toLowerCase() == 'rejected';
    final stubHeight = 44.h;
    final notch = 7.w;

    final meta = [
      if (item.destination != null) item.destination!,
      paidAt != null ? formatTanggal(paidAt) : item.submissionDate,
    ].join(' · ');

    return ClipPath(
      clipper: _ReceiptClipper(
        stubHeight: stubHeight,
        radius: 14.r,
        notch: notch,
      ),
      child: Material(
        // The status tint carries the shape on its own — no border, no shadow.
        // Kept faint: it has to sit behind body text without dragging the
        // contrast down, and a wall of saturated rows would read as an alert
        // list rather than a claim list.
        color: accent.withValues(alpha: 0.07),
        child: InkWell(
          onTap: () =>
              Get.toNamed(Routes.SETTLEMENT_DETAIL, arguments: item.id),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(15.w, 13.h, 15.w, 13.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.number,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        SettlementStatusChip(item.status),
                      ],
                    ),
                    SizedBox(height: 7.h),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: AppColors.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              // The perforation runs between the two notches the clipper bit
              // out of the card's edges, so the tear reads as one line.
              Padding(
                padding: EdgeInsets.symmetric(horizontal: notch + 5.w),
                child: _Perforation(accent.withValues(alpha: 0.35)),
              ),
              SizedBox(
                height: stubHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15.w),
                  child: Row(
                    children: [
                      Text(
                        'TOTAL',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatRupiah(item.total),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.4,
                          // A rejected claim is money that is not coming, so it
                          // stops reading as a figure worth adding up.
                          color: isRejected
                              ? AppColors.textMuted
                              : AppColors.primary,
                          decoration: isRejected
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The receipt outline: a rounded card with a semicircle bitten out of each
/// side at the tear line. The notches are what make the shape read as a receipt
/// rather than a card with a dashed rule through it.
Path _receiptPath({
  required Size size,
  required double stubHeight,
  required double radius,
  required double notch,
}) {
  final tearY = size.height - stubHeight;

  final card = Path()
    ..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
    );
  final holes = Path()
    ..addOval(Rect.fromCircle(center: Offset(0, tearY), radius: notch))
    ..addOval(
      Rect.fromCircle(center: Offset(size.width, tearY), radius: notch),
    );

  return Path.combine(PathOperation.difference, card, holes);
}

/// Cuts the card to [_receiptPath], so the page canvas shows through the
/// notches instead of them being drawn on.
class _ReceiptClipper extends CustomClipper<Path> {
  /// Height of the stub below the tear.
  final double stubHeight;
  final double radius;
  final double notch;

  const _ReceiptClipper({
    required this.stubHeight,
    required this.radius,
    required this.notch,
  });

  @override
  Path getClip(Size size) => _receiptPath(
    size: size,
    stubHeight: stubHeight,
    radius: radius,
    notch: notch,
  );

  @override
  bool shouldReclip(_ReceiptClipper old) =>
      old.stubHeight != stubHeight ||
      old.radius != radius ||
      old.notch != notch;
}

/// The dashed tear line itself, sized to whatever width it is given.
class _Perforation extends StatelessWidget {
  final Color color;

  const _Perforation(this.color);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(painter: _PerforationPainter(color)),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  static const _dash = 4.0;
  static const _gap = 4.0;

  final Color color;

  const _PerforationPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    for (var x = 0.0; x < size.width; x += _dash + _gap) {
      final end = (x + _dash).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, 0.5), Offset(end, 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter oldDelegate) =>
      oldDelegate.color != color;
}
