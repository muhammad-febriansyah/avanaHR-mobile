import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

/// Status marker for a settlement. The shared [StatusChip] only knows the
/// approve/reject vocabulary; a settlement also passes through a draft and two
/// distinct review desks, so it gets its own labels.
///
/// Rendered as a colored dot plus a label rather than a filled pill: a
/// settlement list is already carrying a column of large rupiah figures, and a
/// row of tinted pills next to them fights for the same attention.
class SettlementStatusChip extends StatelessWidget {
  final String status;

  const SettlementStatusChip(this.status, {super.key});

  static const _labels = <String, String>{
    'draft': 'Draft',
    'submitted': 'Menunggu Manager',
    'manager_approved': 'Menunggu Finance',
    'paid': 'Dibayar',
    'rejected': 'Ditolak',
  };

  /// The human label for a raw status, for callers that render their own pill
  /// (the detail hero puts one on a blue field, where this chip's tint fails).
  static String labelFor(String status) =>
      _labels[status.toLowerCase()] ?? status;

  /// The accent color that goes with a status.
  static Color colorFor(String status) => switch (status.toLowerCase()) {
    'paid' => AppColors.success,
    'rejected' => AppColors.destructive,
    'draft' => AppColors.textMuted,
    _ => AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    final key = status.toLowerCase();
    final color = colorFor(key);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6.w,
          height: 6.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 6.w),
        Text(
          _labels[key] ?? status,
          style: TextStyle(
            color: color,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
