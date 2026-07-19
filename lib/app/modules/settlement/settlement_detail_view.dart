import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/ess_models.dart';
import 'settlement_controller.dart';
import 'widgets/settlement_status_chip.dart';

/// Full settlement: total, trip context, expense lines, receipts and the
/// approval trail. Reached from the settlement list; takes the id via
/// `Get.arguments`.
class SettlementDetailView extends GetView<SettlementController> {
  const SettlementDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final id = Get.arguments as int;

    return AppPage(
      title: 'Settlement Perdin',
      child: FutureBuilder<SettlementDetail>(
        future: controller.detail(id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Loading();
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const EmptyState(
              icon: Iconsax.warning_2,
              message: 'Settlement tidak dapat dimuat.',
            );
          }

          return _Body(snapshot.data!, context: context);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final SettlementDetail data;
  final BuildContext context;

  const _Body(this.data, {required this.context});

  @override
  Widget build(BuildContext _) {
    final travel = data.travel;
    final hasTravel = travel.destination != null || travel.rangeLabel != null;

    // The page canvas is tinted so the white cards read as distinct surfaces —
    // on AppPage's plain white body they would dissolve into the background.
    return ColoredBox(
      color: AppColors.background,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16.w,
          16.h,
          16.w,
          AppPage.bottomNavClearance(context),
        ),
        children: [
          _HeroCard(data),
          if (data.rejectionReason != null) ...[
            SizedBox(height: 12.h),
            _RejectionNote(data.rejectionReason!),
          ],
          if (hasTravel) ...[
            const _SectionLabel('Informasi Perjalanan'),
            _TravelCard(travel),
          ],
          _SectionLabel(
            'Rincian Transaksi',
            trailing: '${data.items.length} item',
          ),
          _TransactionList(data.items),
          const _SectionLabel('Ringkasan Biaya'),
          _AmountCard(data),
          if (!data.payoutAccount.isEmpty) ...[
            const _SectionLabel('Rekening Pembayaran'),
            _PayoutCard(data.payoutAccount),
          ],
          if (data.documents.isNotEmpty) ...[
            _SectionLabel(
              'Dokumen Pendukung',
              trailing: '${data.documents.length} berkas',
            ),
            _DocumentStrip(data.documents),
          ],
          if (data.notes != null && data.notes!.trim().isNotEmpty) ...[
            const _SectionLabel('Catatan'),
            _NotesCard(data.notes!),
          ],
          const _SectionLabel('Alur Proses'),
          _Timeline(data.timeline),
        ],
      ),
    );
  }
}

/// Section heading with the leading brand tick, plus an optional right-aligned
/// count so long sections announce their size before you scroll them.
class _SectionLabel extends StatelessWidget {
  final String text;
  final String? trailing;

  const _SectionLabel(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 22.h, 4.w, 10.h),
      child: Row(
        children: [
          Container(
            width: 3.w,
            height: 13.h,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -.1,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}

/// The headline amount, on brand blue so it carries the page the way the
/// header does. Status, claim number, department and date hang off it.
class _HeroCard extends StatelessWidget {
  final SettlementDetail data;

  const _HeroCard(this.data);

  @override
  Widget build(BuildContext context) {
    final header = data.header;
    final paidAt = header.paidAt;
    final dateLabel = paidAt != null
        ? 'Dibayar ${formatTanggal(paidAt)}'
        : 'Diajukan ${header.submissionDate}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        gradient: const LinearGradient(
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
            padding: EdgeInsets.all(18.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'TOTAL SETTLEMENT',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                    _HeroStatusPill(header.status),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  formatRupiah(header.total),
                  style: TextStyle(
                    fontSize: 30.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -1,
                    height: 1.1,
                  ),
                ),
                if (header.title.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    header.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ],
                SizedBox(height: 14.h),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.22)),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: _HeroFact(Iconsax.receipt_2_1, header.number),
                    ),
                    Expanded(child: _HeroFact(Iconsax.calendar_1, dateLabel)),
                  ],
                ),
                if (data.department != null &&
                    data.department!.trim().isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  _HeroFact(Iconsax.buildings_2, data.department!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Status pill sized for the blue hero: solid white so the status color still
/// carries against the gradient.
class _HeroStatusPill extends StatelessWidget {
  final String status;

  const _HeroStatusPill(this.status);

  @override
  Widget build(BuildContext context) {
    final color = SettlementStatusChip.colorFor(status);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 6.w),
          Text(
            SettlementStatusChip.labelFor(status),
            style: TextStyle(
              color: color,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFact extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroFact(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13.sp, color: Colors.white.withValues(alpha: 0.7)),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ),
      ],
    );
  }
}

/// Destination + dates, over a map preview when the trip carries a pin.
class _TravelCard extends StatelessWidget {
  final SettlementTravel travel;

  const _TravelCard(this.travel);

  @override
  Widget build(BuildContext context) {
    final hasDates = travel.startDate != null && travel.endDate != null;

    return ContentCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          if (travel.hasPin)
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(14.r)),
              child: SizedBox(
                height: 140.h,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _TravelMap(LatLng(travel.latitude!, travel.longitude!)),
                    // Scrim so the destination caption stays legible over
                    // whatever the tiles happen to show.
                    if (travel.destination != null)
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.center,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0x8C000000)],
                            ),
                          ),
                        ),
                      ),
                    if (travel.destination != null)
                      Positioned(
                        left: 14.w,
                        right: 14.w,
                        bottom: 12.h,
                        child: Row(
                          children: [
                            Icon(
                              Iconsax.location,
                              size: 15.sp,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6.w),
                            Expanded(
                              child: Text(
                                travel.destination!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              children: [
                // Without a map the destination has nowhere else to live.
                if (!travel.hasPin && travel.destination != null) ...[
                  _TravelLine(Iconsax.location, 'Tujuan', travel.destination!),
                  if (hasDates || travel.rangeLabel != null)
                    SizedBox(height: 12.h),
                ],
                if (hasDates)
                  _DateRange(
                    start: travel.startDate!,
                    end: travel.endDate!,
                    days: travel.days,
                  )
                else if (travel.rangeLabel != null)
                  _TravelLine(Iconsax.calendar_1, 'Durasi', travel.rangeLabel!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Departure → return, as two dated columns with the trip length between them.
class _DateRange extends StatelessWidget {
  final String start;
  final String end;
  final int? days;

  const _DateRange({required this.start, required this.end, this.days});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _column('Berangkat', start, CrossAxisAlignment.start)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          child: Column(
            children: [
              Icon(
                Iconsax.arrow_right_3,
                size: 15.sp,
                color: AppColors.textMuted,
              ),
              if (days != null) ...[
                SizedBox(height: 4.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(100.r),
                  ),
                  child: Text(
                    '$days hari',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(child: _column('Kembali', end, CrossAxisAlignment.end)),
      ],
    );
  }

  Widget _column(String label, String date, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10.5.sp, color: AppColors.textMuted),
        ),
        SizedBox(height: 3.h),
        Text(
          formatTanggal(date),
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Static (non-interactive) map preview centred on the destination.
class _TravelMap extends StatelessWidget {
  final LatLng point;

  const _TravelMap(this.point);

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: point,
        initialZoom: 13,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'id.avanahr.mobile',
          tileProvider: NetworkTileProvider(),
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: point,
              width: 36.w,
              height: 36.w,
              alignment: Alignment.bottomCenter,
              child: Icon(
                Icons.location_pin,
                color: AppColors.primary,
                size: 36.sp,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TravelLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TravelLine(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34.w,
          height: 34.w,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, size: 16.sp, color: AppColors.primary),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10.5.sp, color: AppColors.textMuted),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Expense lines as one grouped card — a card per line reads as noise once a
/// trip carries a dozen receipts.
class _TransactionList extends StatelessWidget {
  final List<SettlementLine> lines;

  const _TransactionList(this.lines);

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return ContentCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Text(
              'Belum ada rincian transaksi.',
              style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }

    return ContentCard(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Column(
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.only(left: 58.w),
                child: Divider(height: 1, color: AppColors.border),
              ),
            _TransactionRow(lines[i]),
          ],
        ],
      ),
    );
  }
}

/// One expense line: category icon, what it was, and the amount.
class _TransactionRow extends StatelessWidget {
  final SettlementLine line;

  const _TransactionRow(this.line);

  /// Maps the API's category icon hint onto an Iconsax glyph.
  static const _icons = <String, IconData>{
    'flight': Iconsax.airplane,
    'hotel': Iconsax.buildings_2,
    'car': Iconsax.car,
    'medical': Iconsax.health,
    'phone': Iconsax.mobile,
    'cart': Iconsax.shopping_cart,
    'users': Iconsax.people,
    'receipt': Iconsax.receipt_2_1,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
      child: Row(
        children: [
          IconBubble(
            _icons[line.icon] ?? Iconsax.receipt_2_1,
            AppColors.primary,
            size: 36,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.description,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  line.detail ?? line.categoryLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Text(
            formatRupiah(line.amount),
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtotal → tax → total breakdown, with the total set apart on a tinted
/// block so the number you actually care about is not just another row.
class _AmountCard extends StatelessWidget {
  final SettlementDetail data;

  const _AmountCard(this.data);

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      child: Column(
        children: [
          _AmountLine('Subtotal', data.subtotal),
          SizedBox(height: 10.h),
          _AmountLine('Pajak 11%', data.taxAmount),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  formatRupiah(data.header.total),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
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

class _AmountLine extends StatelessWidget {
  final String label;
  final int value;

  const _AmountLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted),
        ),
        Text(
          formatRupiah(value),
          style: TextStyle(
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Where the money lands. The account number is the one thing people copy out
/// of this screen, so it gets the emphasis and a tap-to-copy.
class _PayoutCard extends StatelessWidget {
  final BankAccountInfo account;

  const _PayoutCard(this.account);

  @override
  Widget build(BuildContext context) {
    final number = account.accountNumber;

    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBubble(Iconsax.bank, AppColors.primary, size: 36),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.bankName ?? 'Bank',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (account.accountHolder != null) ...[
                      SizedBox(height: 2.h),
                      Text(
                        account.accountHolder!,
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (number != null) ...[
            SizedBox(height: 12.h),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: number));
                AppToast.success('Nomor rekening disalin.');
              },
              borderRadius: BorderRadius.circular(10.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        number,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(Iconsax.copy, size: 16.sp, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
          if (account.swift != null) ...[
            SizedBox(height: 10.h),
            InfoRow('SWIFT / BIC', account.swift!),
          ],
        ],
      ),
    );
  }
}

/// Receipt thumbnails; tapping one opens it full-screen.
class _DocumentStrip extends StatelessWidget {
  final List<SettlementDocument> documents;

  const _DocumentStrip(this.documents);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 122.w,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 2.w),
        itemCount: documents.length,
        separatorBuilder: (_, _) => SizedBox(width: 10.w),
        itemBuilder: (_, i) => _DocumentTile(documents[i]),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final SettlementDocument document;

  const _DocumentTile(this.document);

  bool get _isImage {
    final name = document.name.toLowerCase();

    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png');
  }

  @override
  Widget build(BuildContext context) {
    final url = document.url;

    return GestureDetector(
      onTap: url == null || !_isImage ? null : () => _preview(context, url),
      child: SizedBox(
        width: 92.w,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 92.w,
              height: 92.w,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: url != null && _isImage
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallbackIcon(),
                    )
                  : _fallbackIcon(),
            ),
            SizedBox(height: 5.h),
            Text(
              document.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.sp, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackIcon() => Center(
    child: Icon(Iconsax.document_text, size: 26.sp, color: AppColors.textMuted),
  );

  void _preview(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(16.w),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14.r),
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

/// Free-text note the claimant left with the submission.
class _NotesCard extends StatelessWidget {
  final String notes;

  const _NotesCard(this.notes);

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      child: Text(
        notes,
        style: TextStyle(
          fontSize: 12.5.sp,
          height: 1.5,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// The submit → manager → finance → paid trail.
class _Timeline extends StatelessWidget {
  final List<SettlementStep> steps;

  const _Timeline(this.steps);

  @override
  Widget build(BuildContext context) {
    // The first step still open is where the claim actually sits right now.
    final currentIndex = steps.indexWhere((s) => !s.done);

    return ContentCard(
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _TimelineStep(
              steps[i],
              isLast: i == steps.length - 1,
              isCurrent: i == currentIndex,
              // The connector below a done step stays green through to the
              // next pending one, so progress reads at a glance.
              connectorDone: steps[i].done,
            ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final SettlementStep step;
  final bool isLast;
  final bool isCurrent;
  final bool connectorDone;

  const _TimelineStep(
    this.step, {
    required this.isLast,
    required this.isCurrent,
    required this.connectorDone,
  });

  @override
  Widget build(BuildContext context) {
    final accent = step.done
        ? AppColors.success
        : (isCurrent ? AppColors.primary : AppColors.border);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 20.w,
                height: 20.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: step.done ? AppColors.success : Colors.transparent,
                  border: Border.all(color: accent, width: 2),
                  shape: BoxShape.circle,
                ),
                child: step.done
                    ? Icon(Icons.check, size: 12.sp, color: Colors.white)
                    : (isCurrent
                          ? Container(
                              width: 7.w,
                              height: 7.w,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.w,
                    color: connectorDone ? AppColors.success : AppColors.border,
                  ),
                ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          step.label,
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            fontWeight: step.done || isCurrent
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: step.done
                                ? AppColors.textPrimary
                                : (isCurrent
                                      ? AppColors.primary
                                      : AppColors.textMuted),
                          ),
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(100.r),
                          ),
                          child: Text(
                            'Sedang berjalan',
                            style: TextStyle(
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (step.at != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      formatTanggalJam(step.at),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Why Finance or the manager sent the claim back. Sits right under the hero —
/// a rejection is the first thing the claimant needs to read.
class _RejectionNote extends StatelessWidget {
  final String reason;

  const _RejectionNote(this.reason);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border(
          left: BorderSide(color: AppColors.destructive, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.info_circle, size: 16.sp, color: AppColors.destructive),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alasan penolakan',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.destructive,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  reason,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.destructive,
                    height: 1.45,
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
