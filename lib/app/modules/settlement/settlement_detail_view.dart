import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_page.dart';
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

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        20.w,
        16.h,
        20.w,
        AppPage.bottomNavClearance(context),
      ),
      children: [
        _TotalCard(data),
        if (travel.destination != null || travel.rangeLabel != null) ...[
          SizedBox(height: 18.h),
          const _SectionLabel('INFORMASI PERJALANAN'),
          SizedBox(height: 8.h),
          _TravelCard(travel),
        ],
        SizedBox(height: 18.h),
        const _SectionLabel('RINCIAN TRANSAKSI'),
        SizedBox(height: 8.h),
        ...data.items.map(_TransactionRow.new),
        SizedBox(height: 18.h),
        const _SectionLabel('RINGKASAN BIAYA'),
        SizedBox(height: 8.h),
        _AmountCard(data),
        if (!data.payoutAccount.isEmpty) ...[
          SizedBox(height: 18.h),
          const _SectionLabel('REKENING PEMBAYARAN'),
          SizedBox(height: 8.h),
          _PayoutCard(data.payoutAccount),
        ],
        if (data.documents.isNotEmpty) ...[
          SizedBox(height: 18.h),
          const _SectionLabel('DOKUMEN PENDUKUNG'),
          SizedBox(height: 8.h),
          _DocumentStrip(data.documents),
        ],
        SizedBox(height: 18.h),
        const _SectionLabel('ALUR PROSES'),
        SizedBox(height: 8.h),
        _Timeline(data.timeline),
        if (data.rejectionReason != null) ...[
          SizedBox(height: 18.h),
          _RejectionNote(data.rejectionReason!),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10.5.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: .7,
        color: AppColors.textMuted,
      ),
    );
  }
}

/// The headline amount plus its status pill.
class _TotalCard extends StatelessWidget {
  final SettlementDetail data;

  const _TotalCard(this.data);

  @override
  Widget build(BuildContext context) {
    final paidAt = data.header.paidAt;

    return ContentCard(
      padding: EdgeInsets.all(16.w),
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
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .7,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              SettlementStatusChip(data.header.status),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            formatRupiah(data.header.total),
            style: TextStyle(
              fontSize: 26.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: -.5,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(
                Iconsax.calendar_1,
                size: 13.sp,
                color: AppColors.textMuted,
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  paidAt != null
                      ? 'Dibayar ${formatTanggal(paidAt)}'
                      : 'Diajukan ${data.header.submissionDate}',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Text(
                data.header.number,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Destination + dates, over a map preview when the trip carries a pin.
class _TravelCard extends StatelessWidget {
  final SettlementTravel travel;

  const _TravelCard(this.travel);

  @override
  Widget build(BuildContext context) {
    final range = travel.rangeLabel;

    return ContentCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          if (travel.hasPin)
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(14.r)),
              child: SizedBox(
                height: 130.h,
                child: _TravelMap(
                  LatLng(travel.latitude!, travel.longitude!),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              children: [
                if (travel.destination != null)
                  _TravelLine(
                    Iconsax.location,
                    'Tujuan',
                    travel.destination!,
                  ),
                if (travel.destination != null && range != null)
                  SizedBox(height: 12.h),
                if (range != null)
                  _TravelLine(Iconsax.calendar_1, 'Durasi', range),
              ],
            ),
          ),
        ],
      ),
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
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
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
                style: TextStyle(
                  fontSize: 10.5.sp,
                  color: AppColors.textMuted,
                ),
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
    return ContentCard(
      margin: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          IconBubble(
            _icons[line.icon] ?? Iconsax.receipt_2_1,
            const Color(0xFF2563EB),
            size: 38,
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
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.textMuted,
                  ),
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

/// Subtotal → tax → total breakdown.
class _AmountCard extends StatelessWidget {
  final SettlementDetail data;

  const _AmountCard(this.data);

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      child: Column(
        children: [
          _AmountLine('Subtotal', data.subtotal),
          SizedBox(height: 8.h),
          _AmountLine('Pajak 11%', data.taxAmount),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            child: Divider(height: 1, color: AppColors.border),
          ),
          _AmountLine('Total', data.header.total, emphasised: true),
        ],
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  final String label;
  final int value;
  final bool emphasised;

  const _AmountLine(this.label, this.value, {this.emphasised = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: emphasised ? 13.5.sp : 12.5.sp,
            fontWeight: emphasised ? FontWeight.w700 : FontWeight.w400,
            color: emphasised
                ? AppColors.textPrimary
                : AppColors.textMuted,
          ),
        ),
        Text(
          formatRupiah(value),
          style: TextStyle(
            fontSize: emphasised ? 15.sp : 12.5.sp,
            fontWeight: emphasised ? FontWeight.w700 : FontWeight.w600,
            color: emphasised ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Where the money lands.
class _PayoutCard extends StatelessWidget {
  final BankAccountInfo account;

  const _PayoutCard(this.account);

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      child: Column(
        children: [
          InfoRow('Bank', account.bankName ?? '-'),
          InfoRow('No. Rekening', account.accountNumber ?? '-'),
          InfoRow('Atas Nama', account.accountHolder ?? '-'),
          if (account.swift != null)
            InfoRow('SWIFT / BIC', account.swift!),
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
      height: 92.w,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
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
      child: Container(
        width: 92.w,
        height: 92.w,
        decoration: BoxDecoration(
          color: AppColors.muted,
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
    );
  }

  Widget _fallbackIcon() => Center(
    child: Icon(
      Iconsax.document_text,
      size: 26.sp,
      color: AppColors.textMuted,
    ),
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

/// The submit → manager → finance → paid trail.
class _Timeline extends StatelessWidget {
  final List<SettlementStep> steps;

  const _Timeline(this.steps);

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _TimelineStep(steps[i], isLast: i == steps.length - 1),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final SettlementStep step;
  final bool isLast;

  const _TimelineStep(this.step, {required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = step.done ? AppColors.success : AppColors.border;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 18.w,
                height: 18.w,
                decoration: BoxDecoration(
                  color: step.done ? AppColors.success : Colors.transparent,
                  border: Border.all(color: color, width: 2),
                  shape: BoxShape.circle,
                ),
                child: step.done
                    ? Icon(Icons.check, size: 11.sp, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2.w, color: AppColors.border),
                ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                      color: step.done
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
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

/// Why Finance or the manager sent the claim back.
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
          Icon(
            Iconsax.info_circle,
            size: 16.sp,
            color: AppColors.destructive,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              reason,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.destructive,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
