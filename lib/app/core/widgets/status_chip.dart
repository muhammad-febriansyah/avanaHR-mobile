import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

/// Colored pill for a request status (pending/approved/rejected/…).
class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    late final Color c;
    if (s == 'approved' || s == 'completed' || s == 'paid') {
      c = AppColors.success;
    } else if (s == 'rejected' || s == 'cancelled') {
      c = AppColors.destructive;
    } else {
      c = AppColors.warning;
    }

    final label = {
      'pending': 'Menunggu',
      'approved': 'Disetujui',
      'rejected': 'Ditolak',
      'completed': 'Selesai',
      'paid': 'Dibayar',
      'cancelled': 'Dibatalkan',
    }[s] ?? status;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Text(label, style: TextStyle(color: c, fontSize: 11.sp, fontWeight: FontWeight.w600)),
    );
  }
}
