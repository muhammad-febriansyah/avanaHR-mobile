import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/theme/app_colors.dart';

/// Confirms the report reached the server. Deliberately a blocking sheet rather
/// than a toast: an employee standing at a client site needs to know the visit
/// was filed before they walk away, and a toast is easy to miss.
Future<void> showVisitSavedSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 28.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Icon(
              Iconsax.tick_circle,
              size: 32.sp,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 18.h),
          Text(
            'Laporan Berhasil Disimpan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Data kunjungan Anda telah terkirim ke server pusat untuk '
            'diverifikasi oleh admin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5.sp,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 22.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: Size.fromHeight(48.h),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('Kembali ke Dashboard'),
            ),
          ),
        ],
      ),
    ),
  );
}
