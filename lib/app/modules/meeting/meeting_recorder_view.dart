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

/// Tonal fills for the transport controls.
///
/// Each state gets a tint plus its own darker ink rather than a solid hue with
/// white on top: neither the brand amber (#F59E0B) nor the green (#22C55E)
/// carries white text at a legible contrast, and a second saturated button
/// beside "Selesai & Ringkas" would fight it for the eye.
const _pauseFill = Color(0xFFFEF3C7);
const _pauseInk = Color(0xFFB45309);
const _resumeFill = Color(0xFFDCFCE7);
const _resumeInk = Color(0xFF15803D);
const _discardFill = Color(0xFFFEF2F2);

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
      // Room at the foot so the last line of the minutes is not tucked under
      // the control bar's shadow.
      padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 18.h),
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
    final max = status.maxMinutes;

    // No ceiling configured: the token wallet is the only limit, and the server
    // stops a room that has gone quiet. Nothing to count down to.
    if (fraction == null || max == null) {
      return Text(
        'Berhenti sendiri bila token habis atau ruangan sunyi',
        style: TextStyle(fontSize: 11.5.sp, color: AppColors.textMuted),
      );
    }

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
                : (c.lines.isNotEmpty ? c.lines.last.text : '');

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

    // Newest first, so the sentence just spoken is never below the fold.
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
              Text(
                'Notulen berjalan',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const Spacer(),
              Text(
                '${c.lines.length} ucapan',
                style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          for (var i = 0; i < recent.length; i++)
            _entry(
              recent[i],
              // Reading upwards, a speaker's name is worth repeating only when
              // the one below them is somebody else.
              showSpeaker:
                  i == recent.length - 1 ||
                  recent[i + 1].speaker != recent[i].speaker,
              latest: i == 0,
            ),
        ],
      ),
    );
  }

  /// One line of the running minutes: time in the margin, words in the column.
  Widget _entry(
    TranscriptLine line, {
    required bool showSpeaker,
    required bool latest,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38.w,
            child: Padding(
              padding: EdgeInsets.only(top: showSpeaker ? 16.h : 2.h),
              child: Text(
                line.timecode,
                style: TextStyle(
                  fontSize: 10.5.sp,
                  color: AppColors.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showSpeaker) ...[
                  Text(
                    line.speakerLabel,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 3.h),
                ],
                Text(
                  line.text,
                  style: TextStyle(
                    fontSize: 13.sp,
                    height: 1.55,
                    // The newest line reads full-strength; older ones recede.
                    color: latest ? AppColors.textPrimary : AppColors.textMuted,
                    fontWeight: latest ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Every control says what it does.
  ///
  /// Three unlabelled circles left people guessing which one ended the meeting
  /// and which one threw it away — a bad thing to guess at with the recording
  /// still running. Stop leads because it is the one people came to press;
  /// discard is a plain word set apart from the two that keep the recording.
  Widget _controls(MeetingRecorderController c) {
    return Container(
      padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 16.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        // Lifts the bar off the transcript scrolling underneath it, so the
        // controls read as a fixed surface rather than the end of the list.
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Obx(() {
        final paused = c.isPaused.value;
        final busy = c.isStopping.value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    icon: paused ? Iconsax.play : Iconsax.pause,
                    label: paused ? 'Lanjutkan' : 'Jeda',
                    // Amber holds the recording, green hands it back — the
                    // button's own colour says which way it will go.
                    background: paused ? _resumeFill : _pauseFill,
                    foreground: paused ? _resumeInk : _pauseInk,
                    onTap: busy
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            c.togglePause();
                          },
                  ),
                ),
                SizedBox(width: 11.w),
                Expanded(
                  flex: 2,
                  child: _actionButton(
                    icon: Iconsax.stop,
                    label: 'Selesai & Ringkas',
                    background: AppColors.primary,
                    foreground: Colors.white,
                    busy: busy,
                    onTap: busy
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            c.stop();
                          },
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            // Tinted rather than bare: a plain red word under two filled
            // buttons reads as a caption, not something you can press. Kept
            // narrow and low-contrast so it stays the last resort.
            TextButton.icon(
              onPressed: busy ? null : () => _confirmDiscard(c),
              style: TextButton.styleFrom(
                backgroundColor: _discardFill,
                foregroundColor: AppColors.danger,
                disabledForegroundColor: AppColors.danger.withValues(
                  alpha: 0.45,
                ),
                minimumSize: Size(0, 44.h),
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              icon: Icon(Iconsax.trash, size: 15.sp),
              label: Text(
                'Buang rekaman',
                style: TextStyle(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color background,
    required Color foreground,
    VoidCallback? onTap,
    bool busy = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background.withValues(alpha: 0.5),
        disabledForegroundColor: foreground.withValues(alpha: 0.7),
        padding: EdgeInsets.symmetric(vertical: 15.h),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
        ),
      ),
      icon: busy
          ? SizedBox(
              width: 16.w,
              height: 16.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(foreground),
              ),
            )
          : Icon(icon, size: 17.sp),
      label: Text(
        label,
        style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w700),
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
          'Rekaman dihentikan sekarang. Kalau belum ada yang terekam, rapat ini '
          'ditandai gagal; kalau sudah ada, bagian itu tetap tersimpan dan '
          'tetap diringkas.',
          style: TextStyle(fontSize: 13.sp, height: 1.5),
        ),
        actionsPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textMuted,
              minimumSize: Size(0, 44.h),
            ),
            child: const Text('Batal'),
          ),
          // The destructive choice is the filled one here, not on the screen
          // behind it: this is the step where the decision is actually made.
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: Size(0, 44.h),
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              'Buang',
              style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w700),
            ),
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
