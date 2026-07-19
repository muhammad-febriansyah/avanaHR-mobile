import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

/// Status pill for a cash advance. The label comes from the API so the two
/// sides cannot drift; only the colour is decided here.
class KasbonStatusChip extends StatelessWidget {
  final String status;
  final String label;

  const KasbonStatusChip(this.status, {required this.label, super.key});

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'disbursed' || 'settled' => AppColors.success,
      'rejected' => AppColors.destructive,
      _ => AppColors.warning,
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
