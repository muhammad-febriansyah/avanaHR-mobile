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

/// One voice, one colour.
///
/// Diarization hands back a speaker number, never a name — "Pembicara 2" is all
/// anybody has until the summariser puts names to voices after the meeting. A
/// tint carries that distinction better than the label does: it survives being
/// read at arm's length across a table.
class _SpeakerTone {
  /// Bubble fill — pale enough that body text keeps its contrast on top.
  final Color fill;

  /// Name, badge and the newest bubble's outline.
  final Color ink;

  const _SpeakerTone(this.fill, this.ink);
}

/// Six hues, then it wraps. A meeting with a seventh distinct voice is rarer
/// than one where two of the six are mistaken for each other.
const _speakerTones = <_SpeakerTone>[
  _SpeakerTone(Color(0xFFEEF2FF), Color(0xFF4338CA)), // indigo
  _SpeakerTone(Color(0xFFECFDF5), Color(0xFF047857)), // emerald
  _SpeakerTone(Color(0xFFFFF7ED), Color(0xFFC2410C)), // orange
  _SpeakerTone(Color(0xFFFDF2F8), Color(0xFFBE185D)), // pink
  _SpeakerTone(Color(0xFFF5F3FF), Color(0xFF6D28D9)), // violet
  _SpeakerTone(Color(0xFFECFEFF), Color(0xFF0E7490)), // cyan
];

_SpeakerTone _toneFor(int speaker) =>
    _speakerTones[speaker.abs() % _speakerTones.length];

/// The recording screen: a clock, and proof the microphone is live.
///
/// Deliberately close to a single column of one idea each — somebody glancing
/// at a phone on a meeting table should read "it is recording, it has been N
/// minutes, it is hearing us" without focusing. No transcript here on purpose;
/// see [_body].
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
                SizedBox(height: 20.h),
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

  /// One line on what the microphone is doing.
  ///
  /// The half-heard sentence used to be quoted here as well as in the minutes
  /// below; one copy is enough, and the minutes are the copy with the timecode
  /// and the speaker attached.
  Widget _listeningCard(MeetingRecorderController c) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
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
    );
  }

  /// The minutes as they arrive, read as a conversation rather than a log.
  ///
  /// Newest first, so the sentence just spoken is never below the fold. Each
  /// voice keeps one colour for the whole meeting, which is what makes a
  /// three-way conversation legible at a glance — the eye follows the tint, not
  /// the repeated "Pembicara 2".
  Widget _transcript(MeetingRecorderController c) {
    final interim = c.interim.value;

    if (c.lines.isEmpty && interim.isEmpty) {
      return _waitingForSound(c);
    }

    final recent = c.lines.reversed.take(12).toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 6.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _transcriptHeader(c),
          SizedBox(height: 10.h),
          // The caveat belongs on the panel, not in a support call afterwards:
          // live speech-to-text mishears names and cuts sentences where the
          // speaker drew breath, and people who do not expect that read the
          // rough draft as the finished minutes.
          _draftNotice(),
          SizedBox(height: 14.h),
          if (interim.isNotEmpty) ...[
            _interimBubble(interim),
            SizedBox(height: 12.h),
          ],
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

  Widget _transcriptHeader(MeetingRecorderController c) {
    final live = !c.isPaused.value;

    return Row(
      children: [
        _Blink(
          active: live,
          child: Container(
            width: 7.w,
            height: 7.w,
            decoration: BoxDecoration(
              color: live ? AppColors.success : AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          'Notulen langsung',
          style: TextStyle(
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: AppColors.muted,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${c.lines.length} ucapan',
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  /// Says out loud that this is a rough draft, so nobody judges the recording
  /// by a mistyped name.
  Widget _draftNotice() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(11.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.info_circle, size: 13.sp, color: const Color(0xFFB45309)),
          SizedBox(width: 7.w),
          Expanded(
            child: Text(
              'Teks kasar dari mesin. Ejaan dan pemenggalan dirapikan AI saat '
              'ringkasan dibuat.',
              style: TextStyle(
                fontSize: 10.5.sp,
                height: 1.4,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The sentence still being revised: no timecode and no speaker yet, because
  /// neither is settled until the provider closes the utterance.
  Widget _interimBubble(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 32.w, child: const _TypingDots()),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4.r),
                topRight: Radius.circular(14.r),
                bottomLeft: Radius.circular(14.r),
                bottomRight: Radius.circular(14.r),
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5.sp,
                height: 1.45,
                fontStyle: FontStyle.italic,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _waitingForSound(MeetingRecorderController c) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 30.h, horizontal: 18.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(13.w),
            decoration: BoxDecoration(
              color: AppColors.muted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.microphone_2,
              size: 20.sp,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            c.isPaused.value ? 'Rekaman dijeda' : 'Menunggu suara pertama…',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Ucapan akan muncul di sini begitu ada yang berbicara.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5.sp,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// One turn of the conversation: whose voice it was, and when.
  ///
  /// The left gutter carries the speaker's badge on the first line of a turn
  /// and the timecode on every line after it — the same 32dp column doing two
  /// jobs, so the words keep a straight left edge either way.
  Widget _entry(
    TranscriptLine line, {
    required bool showSpeaker,
    required bool latest,
  }) {
    final tone = _toneFor(line.speaker);

    return Padding(
      // Keyed so a new line at the top does not re-run the entrance animation
      // on every line beneath it.
      key: ValueKey('${line.atMs}-${line.speaker}'),
      padding: EdgeInsets.only(bottom: 10.h),
      child: _FadeInOnce(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32.w,
              child: showSpeaker
                  ? _speakerBadge(line, tone)
                  : Padding(
                      padding: EdgeInsets.only(top: 11.h),
                      child: Text(
                        line.timecode,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.5.sp,
                          color: AppColors.textMuted.withValues(alpha: 0.8),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
            ),
            SizedBox(width: 9.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showSpeaker) ...[
                    Row(
                      children: [
                        Text(
                          line.speakerLabel,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: tone.ink,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          line.timecode,
                          style: TextStyle(
                            fontSize: 9.5.sp,
                            color: AppColors.textMuted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 5.h),
                  ],
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 13.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: tone.fill,
                      borderRadius: BorderRadius.only(
                        // Square shoulder on the first bubble of a turn: it
                        // points back at the badge that names the speaker.
                        topLeft: Radius.circular(showSpeaker ? 4.r : 14.r),
                        topRight: Radius.circular(14.r),
                        bottomLeft: Radius.circular(14.r),
                        bottomRight: Radius.circular(14.r),
                      ),
                      border: latest
                          ? Border.all(
                              color: tone.ink.withValues(alpha: 0.35),
                              width: 1.2,
                            )
                          : null,
                    ),
                    child: Text(
                      line.text,
                      style: TextStyle(
                        fontSize: 13.sp,
                        height: 1.5,
                        // The newest line reads full-strength; older ones
                        // recede so the eye lands on what was just said.
                        color: latest
                            ? AppColors.textPrimary
                            : AppColors.textPrimary.withValues(alpha: 0.72),
                        fontWeight: latest ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _speakerBadge(TranscriptLine line, _SpeakerTone tone) {
    return Padding(
      padding: EdgeInsets.only(top: 14.h),
      child: Container(
        width: 28.w,
        height: 28.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tone.fill,
          shape: BoxShape.circle,
          border: Border.all(color: tone.ink.withValues(alpha: 0.25)),
        ),
        child: Text(
          '${line.speaker + 1}',
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w800,
            color: tone.ink,
          ),
        ),
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

/// A line slides in once, when it first arrives, and then holds still.
///
/// The list is rebuilt on every settled utterance, so an animation tied to
/// build would re-run down the whole column each time somebody speaks. Keeping
/// the controller in State — and keying each row by its offset — means the
/// motion belongs to the line, not to the rebuild.
class _FadeInOnce extends StatefulWidget {
  final Widget child;

  const _FadeInOnce({required this.child});

  @override
  State<_FadeInOnce> createState() => _FadeInOnceState();
}

class _FadeInOnceState extends State<_FadeInOnce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        // From just above: a new line pushes the older ones down, which is the
        // direction the list actually grows.
        position: Tween(
          begin: const Offset(0, -0.12),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Three dots keeping time while the provider is still revising a sentence.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 15.h),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              // Each dot runs a third of a cycle behind the one before it.
              final phase = (_controller.value - i * 0.18) % 1.0;
              final lift = phase < 0.5 ? phase * 2 : (1 - phase) * 2;

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 1.5.w),
                child: Opacity(
                  opacity: 0.35 + lift * 0.65,
                  child: Container(
                    width: 4.5.w,
                    height: 4.5.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
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
