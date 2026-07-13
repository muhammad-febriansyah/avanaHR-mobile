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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Verifikasi Wajah'),
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2),
          tooltip: 'Batal',
          onPressed: Get.back,
        ),
      ),
      body: Obx(() {
        if (!controller.isReady.value) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            _preview(),
            // Spotlight scrim with an oval cutout over the face frame.
            const Positioned.fill(child: _SpotlightScrim()),
            _cornerFrame(),
            _bottomPanel(),
          ],
        );
      }),
    );
  }

  Widget _preview() {
    final cam = controller.camera;
    if (cam == null) return const SizedBox.shrink();
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: cam.value.previewSize?.height ?? 1,
        height: cam.value.previewSize?.width ?? 1,
        child: CameraPreview(cam),
      ),
    );
  }

  /// Rounded corner brackets that frame the oval capture target.
  Widget _cornerFrame() {
    return Align(
      alignment: const Alignment(0, -0.18),
      child: SizedBox(
        width: 250.w,
        height: 320.w,
        child: Obx(() {
          final color = controller.isBusy.value
              ? AppColors.success
              : Colors.white;
          return CustomPaint(painter: _CornerPainter(color));
        }),
      ),
    );
  }

  Widget _bottomPanel() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
        decoration: const BoxDecoration(color: AppColors.navy),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _hintRow(),
              SizedBox(height: 16.h),
              Obx(
                () => SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton.icon(
                    onPressed: controller.isBusy.value
                        ? null
                        : controller.capture,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      disabledBackgroundColor: AppColors.success.withValues(
                        alpha: 0.5,
                      ),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    icon: controller.isBusy.value
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(Iconsax.scan, size: 20.sp),
                    label: Text(
                      controller.isBusy.value
                          ? 'Memproses…'
                          : 'Verifikasi Wajah',
                      style: TextStyle(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hintRow() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.info_circle, size: 16.sp, color: Colors.white70),
          SizedBox(width: 8.w),
          Flexible(
            child: Text(
              'Posisikan wajah di dalam bingkai, cahaya cukup, mata terbuka.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5.sp,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark scrim over the whole screen with a soft oval hole so the face area
/// stays bright and framed.
class _SpotlightScrim extends StatelessWidget {
  const _SpotlightScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _ScrimPainter()));
  }
}

class _ScrimPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.41);
    final ovalW = 250.w;
    final ovalH = 320.w;
    final hole = Rect.fromCenter(center: center, width: ovalW, height: ovalH);

    final scrim = Path()..addRect(Offset.zero & size);
    final ovalPath = Path()..addOval(hole);
    final diff = Path.combine(PathOperation.difference, scrim, ovalPath);

    canvas.drawPath(
      diff,
      Paint()..color = AppColors.navy.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _ScrimPainter oldDelegate) => false;
}

/// Four rounded corner brackets around the capture oval.
class _CornerPainter extends CustomPainter {
  _CornerPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const len = 26.0;
    const r = 14.0;
    final w = size.width;
    final h = size.height;

    // top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, len + r)
        ..lineTo(0, r)
        ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
        ..lineTo(len + r, 0),
      p,
    );
    // top-right
    canvas.drawPath(
      Path()
        ..moveTo(w - len - r, 0)
        ..lineTo(w - r, 0)
        ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
        ..lineTo(w, len + r),
      p,
    );
    // bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, h - len - r)
        ..lineTo(0, h - r)
        ..arcToPoint(Offset(r, h), radius: const Radius.circular(r))
        ..lineTo(len + r, h),
      p,
    );
    // bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(w - len - r, h)
        ..lineTo(w - r, h)
        ..arcToPoint(Offset(w, h - r), radius: const Radius.circular(r))
        ..lineTo(w, h - len - r),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) =>
      oldDelegate.color != color;
}
