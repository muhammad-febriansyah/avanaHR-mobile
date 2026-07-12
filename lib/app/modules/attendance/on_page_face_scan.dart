import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/vector_math.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';
import '../../data/services/face_detector_service.dart';
import '../../data/services/face_embedder_service.dart';
import '../main/main_controller.dart';
import 'attendance_controller.dart';

/// Live face scanner embedded directly in the Absensi page — no separate
/// camera route. The front camera runs only while the Absensi tab is active
/// (a [MainController.tab] worker starts/stops it) so it never stays on in the
/// background. Not-yet-enrolled users get the two-step (neutral → smile)
/// enrollment inline; enrolled users just capture one frame to clock.
class OnPageFaceScan extends StatefulWidget {
  const OnPageFaceScan({super.key});

  @override
  State<OnPageFaceScan> createState() => _OnPageFaceScanState();
}

class _OnPageFaceScanState extends State<OnPageFaceScan>
    with SingleTickerProviderStateMixin {
  final AttendanceController _attendance = Get.find();
  final MainController _main = Get.find();
  final AvanaApi _api = AvanaApi();
  final FaceDetectorService _detector = FaceDetectorService();
  final FaceEmbedderService _embedder = Get.find();

  CameraController? _cam;
  bool _initializing = false;

  final _busy = false.obs;
  final _enrollStep = 0.obs; // 0 = neutral, 1 = smile (enroll only)
  final List<List<double>> _enrollCaptures = [];

  // Sweeping scan line that signals the camera is live and ready.
  late final AnimationController _scan;

  Worker? _tabWorker;

  bool get _active => _main.tab.value == MainController.attendanceTab;

  @override
  void initState() {
    super.initState();
    _scan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _tabWorker = ever<int>(_main.tab, (i) {
      if (i == MainController.attendanceTab) {
        _ensureCamera();
      } else {
        _releaseCamera();
      }
    });
    if (_active) _ensureCamera();
  }

  Future<void> _ensureCamera() async {
    if (_cam != null || _initializing) return;
    _initializing = true;
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        _initializing = false;
        return;
      }
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        _initializing = false;
        return;
      }
      setState(() => _cam = controller);
    } catch (_) {
      // Permission denied / no camera — the build shows a fallback prompt.
    } finally {
      _initializing = false;
    }
  }

  Future<void> _releaseCamera() async {
    final c = _cam;
    _cam = null;
    if (mounted) setState(() {});
    await c?.dispose();
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
    _scan.dispose();
    _cam?.dispose();
    _detector.dispose();
    super.dispose();
  }

  /// Capture a frame, embed it on-device, then either accumulate an enrollment
  /// step or submit the clock action.
  Future<void> _capture() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized || _busy.value) return;
    if (!_attendance.canClockByLocation) {
      AppToast.warning('Di luar radius kantor. Mendekat ke lokasi untuk absen.');
      return;
    }

    _busy.value = true;
    HapticFeedback.mediumImpact();
    try {
      final shot = await cam.takePicture();
      final faces = await _detector.detectFile(shot.path);
      if (faces.length != 1) {
        AppToast.warning('Pastikan hanya wajah Anda yang terlihat di kamera.');
        return;
      }
      final face = faces.first;
      if (!_detector.isFrontalOpenEyes(face)) {
        AppToast.warning('Hadapkan wajah lurus ke kamera dan buka mata.');
        return;
      }

      final enrolling = !_attendance.requiresFace.value;
      final smiling = face.smilingProbability ?? 0;
      if (enrolling) {
        if (_enrollStep.value == 0 && smiling > 0.5) {
          AppToast.warning('Wajah netral dulu ya (jangan senyum).');
          return;
        }
        if (_enrollStep.value == 1 && smiling < 0.5) {
          AppToast.warning('Belum terdeteksi senyum. Coba senyum lebih lebar.');
          return;
        }
      }

      final embedding = await _embedder.embedFromFile(shot.path, face.boundingBox);
      if (embedding == null) {
        AppToast.error('Model wajah tidak tersedia. Hubungi admin.');
        return;
      }

      if (!enrolling) {
        // Enrolled → send the embedding; the server verifies it on clock.
        await _attendance.clockWithEmbedding(embedding);
        return;
      }

      // Enrollment: two-step active liveness, then enroll + clock.
      _enrollCaptures.add(embedding);
      if (_enrollStep.value == 0) {
        _enrollStep.value = 1;
        AppToast.info('Wajah netral tersimpan. Sekarang senyum.');
        return;
      }
      await _submitEnrollThenClock();
    } catch (_) {
      AppToast.error('Gagal memproses wajah. Coba lagi.');
    } finally {
      _busy.value = false;
    }
  }

  Future<void> _submitEnrollThenClock() async {
    final template = VectorMath.averageNormalized(_enrollCaptures);
    try {
      final res = await _api.enrollFace(template);
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        _attendance.markFaceEnrolled();
        AppToast.success('Wajah terdaftar. Mencatat absen…');
        await _attendance.clockWithEmbedding(null);
      } else {
        AppToast.error(ApiClient.messageFrom(res, 'Gagal mendaftar wajah.'));
        _resetEnroll();
      }
    } catch (_) {
      AppToast.error('Gagal mendaftar wajah. Coba lagi.');
      _resetEnroll();
    }
  }

  void _resetEnroll() {
    _enrollCaptures.clear();
    _enrollStep.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 340.h,
            width: double.infinity,
            child: _cameraArea(),
          ),
          _panel(),
        ],
      ),
    );
  }

  Widget _cameraArea() {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 14.h),
            Text(
              'Menyiapkan kamera…',
              style: TextStyle(color: Colors.white70, fontSize: 12.sp),
            ),
          ],
        ),
      );
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
        const Positioned.fill(child: _OvalScrim()),
        // Sweeping scan line (hidden while processing / under reduced motion).
        Obx(() =>
            _busy.value ? const SizedBox.shrink() : _scanLine(context)),
        Center(
          child: SizedBox(
            width: 200.w,
            height: 250.w,
            child: Obx(() => CustomPaint(
                  painter: _CornerPainter(
                      _busy.value ? AppColors.success : Colors.white),
                )),
          ),
        ),
        // Geofence-blocked veil.
        Obx(() {
          if (_attendance.canClockByLocation) return const SizedBox.shrink();
          return Container(
            color: AppColors.navy.withValues(alpha: 0.72),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.location_slash, color: Colors.white, size: 34.sp),
                SizedBox(height: 10.h),
                Text(
                  'Di luar radius kantor',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Mendekat ke lokasi untuk absen',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white70, fontSize: 11.5.sp),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// A soft green line sweeping vertically inside the oval — a live-scan cue.
  /// Skipped when the user prefers reduced motion.
  Widget _scanLine(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return const SizedBox.shrink();
    return Center(
      child: SizedBox(
        width: 200.w,
        height: 250.w,
        child: ClipOval(
          child: AnimatedBuilder(
            animation: _scan,
            builder: (_, _) => Align(
              alignment: Alignment(0, (_scan.value * 2) - 1),
              child: Container(
                height: 2,
                margin: EdgeInsets.symmetric(horizontal: 24.w),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 18.h),
      color: AppColors.navy,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(() => Text(
                _instruction(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5.sp,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              )),
          SizedBox(height: 14.h),
          Obx(() {
            final isIn = _attendance.today.value?.canClockIn ?? true;
            final busy = _busy.value || _attendance.isClocking.value;
            final blocked = !_attendance.canClockByLocation;
            return SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton.icon(
                onPressed: busy || blocked ? null : _capture,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  disabledBackgroundColor:
                      Colors.white.withValues(alpha: 0.16),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                icon: busy
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Icon(Iconsax.scan, size: 20.sp),
                label: Text(
                  busy
                      ? 'Memproses…'
                      : blocked
                          ? 'Di luar radius'
                          : isIn
                              ? 'Absen Masuk (Wajah)'
                              : 'Absen Pulang (Wajah)',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
                ),
              ),
            );
          }),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.shield_tick, size: 12.sp, color: Colors.white54),
              SizedBox(width: 6.w),
              Flexible(
                child: Text(
                  'Hanya data wajah (bukan foto) yang dikirim.',
                  style: TextStyle(color: Colors.white54, fontSize: 10.sp),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _instruction() {
    if (!_attendance.canClockByLocation) {
      return 'Dekati lokasi kantor agar bisa absen dengan wajah.';
    }
    if (_attendance.requiresFace.value) {
      return 'Posisikan wajah di dalam bingkai, lalu tekan Absen.';
    }
    return _enrollStep.value == 0
        ? 'Daftar wajah • Langkah 1/2: wajah netral (jangan senyum).'
        : 'Daftar wajah • Langkah 2/2: senyum, lalu tekan Absen.';
  }
}

/// Dark scrim with a soft oval hole so the face area stays bright and framed.
class _OvalScrim extends StatelessWidget {
  const _OvalScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _ScrimPainter()));
  }
}

class _ScrimPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final hole = Rect.fromCenter(center: center, width: 200.w, height: 250.w);
    final scrim = Path()..addRect(Offset.zero & size);
    final oval = Path()..addOval(hole);
    canvas.drawPath(
      Path.combine(PathOperation.difference, scrim, oval),
      Paint()..color = AppColors.navy.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant _ScrimPainter oldDelegate) => false;
}

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
    const len = 24.0;
    const r = 14.0;
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
  bool shouldRepaint(covariant _CornerPainter oldDelegate) =>
      oldDelegate.color != color;
}
