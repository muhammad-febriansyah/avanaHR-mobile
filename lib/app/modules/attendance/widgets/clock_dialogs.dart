import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/theme/app_colors.dart';

/// Feedback dialogs for the attendance clock flow: a "register your face first"
/// prompt, a blocking loader while the punch is submitted, and a success/fail
/// result card afterwards.

/// White rounded dialog shell shared by every card below.
Widget _shell(Widget child) {
  return Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: EdgeInsets.symmetric(horizontal: 36.w),
    child: Container(
      padding: EdgeInsets.fromLTRB(22.w, 24.h, 22.w, 20.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: child,
    ),
  );
}

Widget _iconCircle(IconData icon, Color color) {
  return Container(
    width: 60.w,
    height: 60.w,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: 30.sp, color: color),
  );
}

Widget _dialogButton(
  String label,
  VoidCallback onTap, {
  required bool filled,
}) {
  return SizedBox(
    height: 46.h,
    child: filled
        ? ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w700),
            ),
          )
        : OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textMuted,
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w600),
            ),
          ),
  );
}

/// Ask the user to enrol their face before clocking. Returns true to proceed to
/// enrollment, false if they dismiss.
Future<bool> confirmFaceEnroll() async {
  final res = await Get.dialog<bool>(
    _shell(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconCircle(Iconsax.user_tag, AppColors.primary),
          SizedBox(height: 16.h),
          Text(
            'Wajah Belum Terdaftar',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Absensi memakai pengenalan wajah. Daftarkan wajah Anda dulu, '
            'lalu absen langsung dilanjutkan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5.sp,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: _dialogButton(
                  'Nanti',
                  () => Get.back(result: false),
                  filled: false,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _dialogButton(
                  'Daftar Wajah',
                  () => Get.back(result: true),
                  filled: true,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    barrierDismissible: false,
  );

  return res ?? false;
}

/// Show a blocking loader while a punch is submitted. No-op if one is already
/// open. Pair with [hideClockLoader].
void showClockLoader([String message = 'Memproses absensi…']) {
  if (Get.isDialogOpen ?? false) {
    return;
  }
  Get.dialog(
    PopScope(
      canPop: false,
      child: _shell(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 46.w,
              height: 46.w,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Mohon tunggu sebentar.',
              style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    ),
    barrierDismissible: false,
  );
}

/// Close the loader (or any open dialog) if present.
void hideClockLoader() {
  if (Get.isDialogOpen ?? false) {
    Get.back();
  }
}

/// Success / failure result card. Auto-dismisses after a couple of seconds, or
/// on tapping "Selesai".
Future<void> showClockResult({
  required bool success,
  required String message,
}) {
  return Get.dialog(
    _ResultDialog(success: success, message: message),
    barrierDismissible: true,
  );
}

class _ResultDialog extends StatefulWidget {
  final bool success;
  final String message;

  const _ResultDialog({required this.success, required this.message});

  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.success ? AppColors.success : AppColors.destructive;
    return _shell(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconCircle(
            widget.success ? Iconsax.tick_circle : Iconsax.close_circle,
            color,
          ),
          SizedBox(height: 16.h),
          Text(
            widget.success ? 'Berhasil' : 'Gagal',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5.sp,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 18.h),
          SizedBox(
            width: double.infinity,
            child: _dialogButton(
              'Selesai',
              () => Get.back(),
              filled: widget.success,
            ),
          ),
        ],
      ),
    );
  }
}
