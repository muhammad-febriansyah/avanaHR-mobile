import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../data/services/connectivity_service.dart';
import '../theme/app_colors.dart';

/// Popup shown when the internet becomes unreachable. Auto-dismissed by the
/// caller once the connection is restored; the user can also retry or close.
class ConnectionDialog extends StatelessWidget {
  final bool offline;
  const ConnectionDialog({super.key, required this.offline});

  @override
  Widget build(BuildContext context) {
    final color = offline ? AppColors.destructive : AppColors.warning;
    final icon = offline ? Iconsax.wifi_square : Iconsax.warning_2;
    final title = offline ? 'Tidak Ada Koneksi' : 'Koneksi Tidak Stabil';
    final body = offline
        ? 'Perangkat tidak terhubung ke internet. Absen tetap tersimpan & terkirim otomatis begitu online.'
        : 'Terhubung, tapi internet tidak terjangkau (sinyal lemah / jaringan bermasalah). Coba pindah ke tempat dengan sinyal lebih baik.';

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
      insetPadding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Padding(
        padding: EdgeInsets.fromLTRB(22.w, 24.h, 22.w, 18.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58.w,
              height: 58.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28.sp),
            ),
            SizedBox(height: 16.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5.sp,
                color: AppColors.textMuted,
                height: 1.45,
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      side: BorderSide(color: AppColors.border),
                      minimumSize: Size(0, 46.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    onPressed: () => Get.back(),
                    child: Text(
                      'Tutup',
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: Size(0, 46.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    onPressed: () => Get.find<ConnectivityService>().recheck(),
                    icon: Icon(Iconsax.refresh, size: 17.sp),
                    label: Text(
                      'Coba Lagi',
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
