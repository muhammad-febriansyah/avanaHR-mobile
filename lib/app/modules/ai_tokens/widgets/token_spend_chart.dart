import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formats.dart';
import '../../../data/models/ai_models.dart';

final _count = NumberFormat.decimalPattern('id');

/// How much AI budget was spent per day or per month.
///
/// One measure, one hue: the bar being read is brand blue and the rest recede,
/// so the eye lands on the bucket in question rather than on a wall of colour.
/// Phones have no hover, so a tap takes its place — the headline above the
/// plot states the selected bucket, which also keeps the bars themselves free
/// of a number on every column.
class TokenSpendChart extends StatefulWidget {
  const TokenSpendChart({super.key, required this.points, required this.monthly});

  final List<AiTokenSpendPoint> points;

  /// Buckets are months rather than days — changes only how a bucket is named.
  final bool monthly;

  @override
  State<TokenSpendChart> createState() => _TokenSpendChartState();
}

class _TokenSpendChartState extends State<TokenSpendChart> {
  int? _selected;

  @override
  void didUpdateWidget(TokenSpendChart old) {
    super.didUpdateWidget(old);

    // Switching between days and months makes the old index meaningless.
    if (old.monthly != widget.monthly) {
      _selected = null;
    }
  }

  /// Reads as "the latest bucket" until the reader picks another one.
  int get _focus => _selected ?? widget.points.length - 1;

  String _caption(AiTokenSpendPoint point) {
    if (widget.monthly) {
      final month = DateTime.tryParse('${point.key}-01');

      return month == null ? point.label : monthLabel(month.month, month.year);
    }

    final day = DateTime.tryParse(point.key);

    if (day == null) {
      return point.label;
    }

    final today = DateTime.now();
    final isToday =
        day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;

    return isToday ? 'Hari ini' : '${point.label}, ${formatTanggalLokal(day)}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return const SizedBox.shrink();
    }

    final point = widget.points[_focus];
    final peak = widget.points.map((p) => p.tokens).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _caption(point),
          style: TextStyle(fontSize: 11.5.sp, color: AppColors.textMuted),
        ),
        SizedBox(height: 2.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _count.format(point.tokens),
              style: TextStyle(
                fontSize: 26.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(width: 5.w),
            Text(
              'token',
              style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        SizedBox(
          height: 118.h,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < widget.points.length; i++)
                Expanded(
                  child: _bar(
                    index: i,
                    point: widget.points[i],
                    peak: peak,
                    active: i == _focus,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bar({
    required int index,
    required AiTokenSpendPoint point,
    required int peak,
    required bool active,
  }) {
    // Nothing spent anywhere still deserves a visible baseline, so an empty
    // chart draws stubs rather than collapsing to a line of labels.
    final fraction = peak == 0 ? 0.0 : point.tokens / peak;
    final height = 6.h + (86.h * fraction);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selected = index),
      child: Padding(
        // A 2px gutter each side keeps neighbouring bars from reading as one
        // block, and widens the tap target past the bar itself.
        padding: EdgeInsets.symmetric(horizontal: 2.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              height: height,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.vertical(top: Radius.circular(4.r)),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              point.label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
