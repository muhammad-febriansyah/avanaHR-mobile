import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import 'face_enroll_controller.dart';

const _bg = Color(0xFF0B1020);

/// Face enrollment screen: full-bleed camera with green corner brackets framing
/// the centre, a light top bar, and a step/status card at the bottom.
class FaceEnrollView extends StatefulWidget {
  const FaceEnrollView({super.key});

  @override
  State<FaceEnrollView> createState() => _FaceEnrollViewState();
}

class _FaceEnrollViewState extends State<FaceEnrollView>
    with SingleTickerProviderStateMixin {
  final FaceEnrollController c = Get.find();
  late final AnimationController _sweep;

  double get _frame => 280.w;

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
            const Positioned.fill(child: IgnorePointer(child: _EdgeGradient())),
            _frameArea(),
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

  Widget _frameArea() {
    return Align(
      alignment: const Alignment(0, -0.16),
      child: SizedBox(
        width: _frame,
        height: _frame,
        child: Stack(
          children: [
            Obx(() {
              final searching = !c.faceOk.value && !c.isBusy.value;
              final reduceMotion =
                  MediaQuery.maybeOf(context)?.disableAnimations ?? false;
              if (!searching || reduceMotion) return const SizedBox.shrink();
              return ClipRRect(
                borderRadius: BorderRadius.circular(28.r),
                child: AnimatedBuilder(
                  animation: _sweep,
                  builder: (_, _) => Align(
                    alignment: Alignment(0, (_sweep.value * 2) - 1),
                    child: Container(
                      height: 2,
                      margin: EdgeInsets.symmetric(horizontal: 20.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.success.withValues(alpha: 0),
                            AppColors.success,
                            AppColors.success.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            Positioned.fill(
              child: Obx(
                () => CustomPaint(
                  painter: _CornerPainter(
                    c.faceOk.value ? AppColors.success : Colors.white,
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
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 0),
          child: Row(
            children: [
              _glassButton(Iconsax.arrow_left_2, c.cancel),
              SizedBox(width: 8.w),
              Text(
                'Daftar Wajah',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100.r),
      child: Container(
        width: 42.w,
        height: 42.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20.sp),
      ),
    );
  }

  Widget _bottomPanel() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(() => _stepPill()),
              SizedBox(height: 12.h),
              Obx(() => _statusPill()),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.shield_tick, size: 12.sp, color: Colors.white60),
                  SizedBox(width: 6.w),
                  Flexible(
                    child: Text(
                      'Hanya data wajah (bukan foto) yang dikirim.',
                      style: TextStyle(
                        color: Colors.white60,
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

  Widget _stepPill() {
    final s = c.step.value;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepDot(s >= 0),
          SizedBox(width: 5.w),
          _stepDot(s >= 1),
          SizedBox(width: 9.w),
          Text(
            s == 0 ? 'Langkah 1/2 · Wajah netral' : 'Langkah 2/2 · Senyum',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepDot(bool active) {
    return Container(
      width: 7.w,
      height: 7.w,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.4),
        shape: BoxShape.circle,
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
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 13.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14.r),
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

class _EdgeGradient extends StatelessWidget {
  const _EdgeGradient();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.18, 0.72, 1],
          colors: [
            _bg.withValues(alpha: 0.8),
            _bg.withValues(alpha: 0),
            _bg.withValues(alpha: 0),
            _bg.withValues(alpha: 0.88),
          ],
        ),
      ),
    );
  }
}

/// Four rounded L-shaped corner brackets framing the capture window; turns
/// green once a valid face is detected.
class _CornerPainter extends CustomPainter {
  _CornerPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const len = 36.0;
    const r = 20.0;
    final w = size.width;
    final h = size.height;

    canvas.drawPath(
      Path()
        ..moveTo(0, len + r)
        ..lineTo(0, r)
        ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
        ..lineTo(len + r, 0),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - len - r, 0)
        ..lineTo(w - r, 0)
        ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
        ..lineTo(w, len + r),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, h - len - r)
        ..lineTo(0, h - r)
        ..arcToPoint(Offset(r, h), radius: const Radius.circular(r))
        ..lineTo(len + r, h),
      p,
    );
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
  bool shouldRepaint(covariant _CornerPainter old) => old.color != color;
}
