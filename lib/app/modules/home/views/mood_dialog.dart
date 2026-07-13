import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/theme/app_colors.dart';
import '../controllers/home_controller.dart';

/// Anonymous daily mood check-in, shown as a popup (auto once per day when not
/// yet checked in, or on demand from the "Feeling" quick action).
class MoodDialog extends StatelessWidget {
  const MoodDialog({super.key});

  static const _moods = <(String, String, String)>[
    ('sangat_baik', '😄', 'Sangat baik'),
    ('baik', '🙂', 'Baik'),
    ('biasa', '😐', 'Biasa'),
    ('kurang', '🙁', 'Kurang'),
    ('buruk', '😣', 'Buruk'),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bagaimana perasaanmu hari ini?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                      fontSize: 15.sp,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: Get.back,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.all(4.w),
                    child: Icon(
                      Iconsax.close_circle,
                      size: 22.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              'Sekali ketuk. Hanya untukmu & HR, anonim.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
            ),
            SizedBox(height: 20.h),
            Obx(() {
              final selected = controller.selectedMood.value;
              return Row(
                children: _moods
                    .map((m) => _moodButton(controller, m, selected == m.$1))
                    .toList(),
              );
            }),
            SizedBox(height: 12.h),
            Center(
              child: TextButton(
                onPressed: Get.back,
                style: TextButton.styleFrom(
                  minimumSize: Size(44.w, 44.h),
                  foregroundColor: AppColors.textMuted,
                ),
                child: Text(
                  'Nanti saja',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moodButton(
    HomeController controller,
    (String, String, String) m,
    bool selected,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Get.back();
          controller.submitMood(m.$1);
        },
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 3.w),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.muted,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                alignment: Alignment.center,
                child: Text(m.$2, style: TextStyle(fontSize: 24.sp)),
              ),
              SizedBox(height: 6.h),
              Text(
                m.$3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textMuted,
                  fontSize: 9.5.sp,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
