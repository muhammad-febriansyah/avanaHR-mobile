import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

/// Status pill for a settlement. The shared [StatusChip] only knows the
/// approve/reject vocabulary; a settlement also passes through a draft and two
/// distinct review desks, so it gets its own labels.
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

  @override
  Widget build(BuildContext context) {
    final key = status.toLowerCase();

    final color = switch (key) {
      'paid' => AppColors.success,
      'rejected' => AppColors.destructive,
      'draft' => AppColors.textMuted,
      _ => AppColors.warning,
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Text(
        _labels[key] ?? status,
        style: TextStyle(
          color: color,
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
