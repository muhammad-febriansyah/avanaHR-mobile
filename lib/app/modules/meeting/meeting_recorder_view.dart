import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../data/models/meeting.dart';
import 'meeting_recorder_controller.dart';
import 'widgets/waveform.dart';

/// The recording screen: a clock, proof the microphone is live, and the words
/// as they settle.
///
/// Deliberately close to a single column of one idea each — somebody glancing
/// at a phone on a meeting table should read "it is recording, it has been N
/// minutes, it heard that last sentence" without focusing.
class MeetingRecorderView extends StatelessWidget {
  final MeetingItem meeting;
  final MeetingRecorderStatus status;

  const MeetingRecorderView({
    super.key,
    required this.meeting,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final c = Get.put(
      MeetingRecorderController(meeting: meeting, status: status),
      tag: 'meeting-${meeting.id}',
    );

    return PopScope(
      // Leaving by accident would abandon a live recording, so the way out is
      // the explicit Stop or Discard button.
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.primary,
          body: Column(
            children: [
              _header(c),
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: AppColors.background,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Expanded(child: _body(c)),
                        _controls(c),
                      ],
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

  Widget _header(MeetingRecorderController c) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryHover],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: CustomPaint(painter: const BrandMeshPainter()),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Obx(() => _statusPill(c))),
                      Obx(
                        () => Text(
                          c.isPaused.value ? 'Dijeda' : 'Merekam',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    meeting.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if ((meeting.location ?? '').isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 3.h),
                      child: Text(
                        meeting.location!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12.5.sp,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The red REC badge — pulsing while live, still while paused.
  Widget _statusPill(MeetingRecorderController c) {
    final paused = c.isPaused.value;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Blink(
              active: !paused,
              child: Container(
                width: 7.w,
                height: 7.w,
                decoration: BoxDecoration(
                  color: paused ? Colors.white70 : const Color(0xFFFF6B6B),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SizedBox(width: 7.w),
            Text(
              paused ? 'PAUSED' : 'RECORDING',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(MeetingRecorderController c) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 8.h),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 22.h),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22.r),
            ),
            child: Column(
              children: [
                Obx(
                  () => Text(
                    c.clock,
                    style: TextStyle(
                      fontSize: 42.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                      letterSpacing: 1.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                Obx(() => _ceilingHint(c)),
                SizedBox(height: 18.h),
                Obx(
                  () => Waveform(
                    levels: c.levels.toList(),
                    paused: c.isPaused.value,
                  ),
                ),
                SizedBox(height: 20.h),
                _listeningCard(c),
              ],
            ),
          ),
          SizedBox(height: 14.h),
          Obx(() => _transcript(c)),
        ],
      ),
    );
  }

  /// How much of the allowed recording length is used. Shown only once it
  /// starts to matter — a progress bar from minute one is just noise.
  Widget _ceilingHint(MeetingRecorderController c) {
    final fraction = c.ceilingFraction;
    final max = status.maxMinutes ?? 180;

    if (fraction < 0.6) {
      return Text(
        'Batas rekaman $max menit',
        style: TextStyle(fontSize: 11.5.sp, color: AppColors.textMuted),
      );
    }

    final left = (max - c.elapsed.value.inMinutes).clamp(0, max);

    return Column(
      children: [
        Text(
          'Sisa $left menit dari batas $max menit',
          style: TextStyle(
            fontSize: 11.5.sp,
            color: fraction > 0.85 ? AppColors.danger : AppColors.warning,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 4.h,
            backgroundColor: AppColors.muted,
            valueColor: AlwaysStoppedAnimation(
              fraction > 0.85 ? AppColors.danger : AppColors.warning,
            ),
          ),
        ),
      ],
    );
  }

  /// "AI sedang mendengarkan", plus the sentence currently being revised.
  Widget _listeningCard(MeetingRecorderController c) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Iconsax.magicpen, size: 15.sp, color: Colors.white),
              ),
              SizedBox(width: 11.w),
              Expanded(
                child: Obx(
                  () => Text(
                    c.isPaused.value
                        ? 'Dijeda — mikrofon tidak aktif'
                        : 'AI sedang mendengarkan dan menyiapkan ringkasan…',
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      height: 1.35,
                      color: AppColors.navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Obx(() {
            final text = c.interim.value.isNotEmpty
                ? c.interim.value
                : (c.lines.isNotEmpty ? c.lines.last : '');

            if (text.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '“$text”',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Everything settled so far, newest first so the latest is never off-screen.
  Widget _transcript(MeetingRecorderController c) {
    if (c.lines.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 26.h, horizontal: 18.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18.r),
        ),
        child: Column(
          children: [
            Icon(Iconsax.microphone_2, size: 22.sp, color: AppColors.textMuted),
            SizedBox(height: 10.h),
            Text(
              'Menunggu suara pertama…',
              style: TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    final recent = c.lines.reversed.take(12).toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.document_text, size: 15.sp, color: AppColors.primary),
              SizedBox(width: 8.w),
              Text(
                'Transkrip langsung',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const Spacer(),
              Text(
                '${c.lines.length} kalimat',
                style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          for (var i = 0; i < recent.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Text(
                recent[i],
                style: TextStyle(
                  fontSize: 13.sp,
                  height: 1.55,
                  // The newest line reads full-strength; older ones recede.
                  color: i == 0 ? AppColors.textPrimary : AppColors.textMuted,
                  fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _controls(MeetingRecorderController c) {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 14.h, 24.w, 18.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Obx(
        () => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _roundButton(
              icon: Iconsax.close_circle,
              background: AppColors.muted,
              foreground: AppColors.textMuted,
              size: 52,
              onTap: c.isStopping.value ? null : () => _confirmDiscard(c),
            ),
            _roundButton(
              icon: c.isPaused.value ? Iconsax.play : Iconsax.pause,
              background: AppColors.primary,
              foreground: Colors.white,
              size: 74,
              onTap: c.isStopping.value ? null : c.togglePause,
            ),
            _roundButton(
              icon: Iconsax.stop,
              background: AppColors.navy,
              foreground: Colors.white,
              size: 52,
              busy: c.isStopping.value,
              onTap: c.isStopping.value ? null : c.stop,
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required Color background,
    required Color foreground,
    required double size,
    VoidCallback? onTap,
    bool busy = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size.w,
        height: size.w,
        decoration: BoxDecoration(
          color: onTap == null ? background.withValues(alpha: 0.5) : background,
          shape: BoxShape.circle,
        ),
        child: busy
            ? Padding(
                padding: EdgeInsets.all(size.w * 0.32),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(foreground),
                ),
              )
            : Icon(icon, color: foreground, size: (size * 0.42).sp),
      ),
    );
  }

  Future<void> _confirmDiscard(MeetingRecorderController c) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        title: Text(
          'Buang rekaman ini?',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Rekaman dihentikan tanpa dibuatkan ringkasan. Transkrip yang sudah '
          'terkirim tetap tersimpan di daftar rapat.',
          style: TextStyle(fontSize: 13.sp, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('Buang', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true) await c.discard();
  }
}

/// Slow pulse for the REC dot.
class _Blink extends StatefulWidget {
  final Widget child;
  final bool active;

  const _Blink({required this.child, required this.active});

  @override
  State<_Blink> createState() => _BlinkState();
}

class _BlinkState extends State<_Blink> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_controller),
      child: widget.child,
    );
  }
}
