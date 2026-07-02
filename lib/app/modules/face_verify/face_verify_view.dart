import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import 'face_verify_controller.dart';

class FaceVerifyView extends GetView<FaceVerifyController> {
  const FaceVerifyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Verifikasi Wajah'),
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
      color: AppColors.navy,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Posisikan wajah di dalam bingkai, lalu tekan Verifikasi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 13.5.sp, height: 1.4),
          ),
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
                      : Icon(Iconsax.scan, size: 18.sp, color: Colors.white),
                  label: Text(
                    controller.isBusy.value ? 'Memproses...' : 'Verifikasi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
