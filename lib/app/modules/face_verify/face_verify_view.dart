import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import 'face_verify_controller.dart';

const _bg = Color(0xFF0B1020); // deep brand navy for camera immersion

class FaceVerifyView extends StatefulWidget {
  const FaceVerifyView({super.key});

  @override
  State<FaceVerifyView> createState() => _FaceVerifyViewState();
}

class _FaceVerifyViewState extends State<FaceVerifyView>
    with SingleTickerProviderStateMixin {
  final FaceVerifyController c = Get.find();
  late final AnimationController _sweep;

  // Oval capture window — kept in sync with the scrim hole (_ScrimPainter).
  double get _ovalW => 260.w;
  double get _ovalH => 330.w;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Obx(() {
        if (!c.isReady.value) return _loading();
        return Stack(
          fit: StackFit.expand,
          children: [
            _preview(),
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _ScrimPainter()),
              ),
            ),
            _ovalArea(),
            _topBar(),
            _bottomPanel(),
          ],
        );
      }),
    );
  }

  Widget _loading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16.h),
          Obx(
            () => Text(
              c.hint.value,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12.5.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    final cam = c.camera;
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

  Widget _ovalArea() {
    return Align(
      alignment: const Alignment(0, -0.18),
      child: SizedBox(
        width: _ovalW,
        height: _ovalH,
        child: Stack(
          children: [
            // Sweeping scan line while searching.
            Obx(() {
              final searching = !c.faceOk.value && !c.isBusy.value;
              final reduceMotion =
                  MediaQuery.maybeOf(context)?.disableAnimations ?? false;
              if (!searching || reduceMotion) return const SizedBox.shrink();
              return ClipOval(
                child: AnimatedBuilder(
                  animation: _sweep,
                  builder: (_, _) => Align(
                    alignment: Alignment(0, (_sweep.value * 2) - 1),
                    child: Container(
                      height: 2,
                      margin: EdgeInsets.symmetric(horizontal: 26.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0),
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            // Reactive oval ring.
            Positioned.fill(
              child: Obx(
                () => CustomPaint(
                  painter: _RingPainter(
                    c.faceOk.value ? AppColors.success : Colors.white,
                    glow: c.faceOk.value,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 0),
        child: Row(
          children: [
            _glassButton(Iconsax.close_circle, c.cancel),
            Expanded(
              child: Text(
                'Verifikasi Wajah',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: 44.w),
          ],
        ),
      ),
    );
  }

  Widget _glassButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100.r),
      child: Container(
        width: 44.w,
        height: 44.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22.sp),
      ),
    );
  }

  Widget _bottomPanel() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 22.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(() => _statusPill()),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.shield_tick, size: 12.sp, color: Colors.white54),
                  SizedBox(width: 6.w),
                  Flexible(
                    child: Text(
                      'Hanya data wajah (bukan foto) yang dikirim.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10.5.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill() {
    final busy = c.isBusy.value;
    final ok = c.faceOk.value;
    final color = ok ? AppColors.success : Colors.white;

    Widget leading;
    if (busy) {
      leading = SizedBox(
        width: 18.w,
        height: 18.w,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
    } else if (ok) {
      leading = Icon(Iconsax.tick_circle, size: 18.sp, color: color);
    } else {
      leading = Icon(Iconsax.scan, size: 18.sp, color: Colors.white);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: ok ? 0.5 : 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          SizedBox(width: 10.w),
          Flexible(
            child: Text(
              c.hint.value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark scrim over the whole screen with a soft oval hole so the face stays
/// bright and framed.
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.41);
    final hole = Rect.fromCenter(center: center, width: 260.w, height: 330.w);
    final scrim = Path()..addRect(Offset.zero & size);
    final oval = Path()..addOval(hole);
    canvas.drawPath(
      Path.combine(PathOperation.difference, scrim, oval),
      Paint()..color = _bg.withValues(alpha: 0.86),
    );
  }

  @override
  bool shouldRepaint(covariant _ScrimPainter oldDelegate) => false;
}

/// A continuous oval ring around the capture window; glows green once a valid
/// face is framed.
class _RingPainter extends CustomPainter {
  _RingPainter(this.color, {this.glow = false});
  final Color color;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final oval = (Offset.zero & size).deflate(2);
    if (glow) {
      canvas.drawOval(
        oval,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawOval(
      oval,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.glow != glow;
}
