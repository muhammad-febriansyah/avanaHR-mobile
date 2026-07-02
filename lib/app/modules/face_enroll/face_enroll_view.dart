import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import 'face_enroll_controller.dart';

class FaceEnrollView extends GetView<FaceEnrollController> {
  const FaceEnrollView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Daftar Wajah'),
      ),
      body: Obx(() {
        if (!controller.isReady.value) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        return Column(
          children: [
            Expanded(child: _preview()),
            _panel(),
          ],
        );
      }),
    );
  }

  Widget _preview() {
    final cam = controller.camera;
    if (cam == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: cam.value.previewSize?.height ?? 1,
            height: cam.value.previewSize?.width ?? 1,
            child: CameraPreview(cam),
          ),
        ),
        Center(
          child: Container(
            width: 240.w,
            height: 300.h,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 2),
              borderRadius: BorderRadius.circular(160),
            ),
          ),
        ),
      ],
    );
  }

  Widget _panel() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
      decoration: const BoxDecoration(color: AppColors.navy),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(() => _stepDots()),
          SizedBox(height: 14.h),
          Obx(() => Text(
                controller.instruction,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5.sp,
                  height: 1.4,
                ),
              )),
          SizedBox(height: 18.h),
          Obx(() => SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: controller.isBusy.value ? null : controller.capture,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: controller.isBusy.value
                      ? SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Iconsax.camera, size: 18.sp, color: Colors.white),
                  label: Text(
                    controller.isBusy.value ? 'Memproses...' : 'Ambil Wajah',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.shield_tick, size: 13.sp, color: Colors.white54),
              SizedBox(width: 6.w),
              Text(
                'Hanya data wajah (bukan foto) yang dikirim.',
                style: TextStyle(color: Colors.white54, fontSize: 10.5.sp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (i) {
        final active = i <= controller.step.value;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          width: i == controller.step.value ? 26.w : 8.w,
          height: 8.h,
          decoration: BoxDecoration(
            color: active ? AppColors.success : Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
