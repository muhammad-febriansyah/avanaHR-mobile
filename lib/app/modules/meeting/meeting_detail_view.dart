import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/meeting.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

/// One meeting: what the AI made of it first, then what was actually said.
///
/// Summary before transcript on purpose — almost nobody re-reads an hour of
/// speech, they want the four paragraphs and the follow-ups. The transcript is
/// there to be checked against, not read front to back.
class MeetingDetailView extends StatefulWidget {
  final int meetingId;
  final AvanaApi? api;

  const MeetingDetailView({super.key, required this.meetingId, this.api});

  @override
  State<MeetingDetailView> createState() => _MeetingDetailViewState();
}

class _MeetingDetailViewState extends State<MeetingDetailView> {
  late final AvanaApi _api;

  final TextEditingController _newItem = TextEditingController();

  MeetingDetail? _detail;
  bool _loading = true;
  bool _showTranscript = false;
  bool _busy = false;

  /// Which analysis is expanded — one at a time, so the page stays scannable.
  String? _openInsight;

  /// Re-checks the meeting while the server is still working on it.
  ///
  /// The screen used to load once and never look again, so a summary that
  /// finished thirty seconds later left the spinner turning until the reader
  /// pulled to refresh or backed out — indistinguishable from a job that had
  /// died. The work is queued and calls the AI three times, so a wait is
  /// normal; being unable to tell a wait from a failure is not.
  Timer? _poll;

  /// How long the poll keeps trying before it stops and says so. Past this the
  /// wait is no longer normal, and a spinner with no end is worse than a
  /// sentence admitting the summary is late.
  static const _pollCeiling = Duration(minutes: 3);

  DateTime? _waitingSince;
  bool _waitedTooLong = false;

  @override
  void dispose() {
    _poll?.cancel();
    _newItem.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? AvanaApi();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await _api.meeting(widget.meetingId);
      if (mounted) setState(() => _detail = detail);
    } on DioException catch (e) {
      AppToast.error(ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
      _syncPolling();
    }
  }

  /// Start or stop the re-check based on what the server last said.
  void _syncPolling() {
    final working = _detail?.meeting.isWorking == true;

    if (!working || _waitedTooLong) {
      _poll?.cancel();
      _poll = null;
      _waitingSince = null;

      return;
    }

    _waitingSince ??= DateTime.now();

    if (DateTime.now().difference(_waitingSince!) >= _pollCeiling) {
      _poll?.cancel();
      _poll = null;
      if (mounted) setState(() => _waitedTooLong = true);

      return;
    }

    // Already watching — the tick that brought us here will schedule the next.
    if (_poll != null) {
      return;
    }

    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) {
        return;
      }

      _load();
    });
  }

  /// Give up on waiting and look once more, from the top.
  Future<void> _retryWaiting() async {
    setState(() {
      _waitedTooLong = false;
      _waitingSince = null;
    });

    await _load();
  }

  /// Run a change that returns the meeting's new state, and redraw from what
  /// the server actually stored rather than from an optimistic guess.
  Future<void> _mutate(Future<MeetingDetail> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final detail = await action();
      if (mounted) setState(() => _detail = detail);
    } on DioException catch (e) {
      AppToast.error(ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
      // A reprocess puts the meeting back to work, so the watch has to start
      // again — and the clock with it, or the fresh attempt would inherit the
      // last one's exhausted patience.
      if (_detail?.meeting.isWorking == true && _waitedTooLong) {
        _waitedTooLong = false;
        _waitingSince = null;
      }
      _syncPolling();
    }
  }

  Future<void> _toggle(MeetingActionItem item) => _mutate(
    () => _api.setMeetingActionItemStatus(
      meetingId: widget.meetingId,
      actionItemId: item.id,
      done: !item.isDone,
    ),
  );

  Future<void> _addItem() async {
    final text = _newItem.text.trim();
    if (text.isEmpty) return;

    await _mutate(
      () => _api.addMeetingActionItem(meetingId: widget.meetingId, text: text),
    );

    _newItem.clear();
  }

  Future<void> _reprocess() async {
    await _mutate(() => _api.reprocessMeeting(widget.meetingId));

    if (mounted && _detail?.meeting.isWorking == true) {
      AppToast.success('Ringkasan sedang dibuat ulang.');
    }
  }

  /// Re-running costs tokens, so it is asked for rather than one tap away.
  Future<void> _confirmReprocess() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        title: Text(
          'Buat ulang ringkasan?',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Ringkasan dan tindak lanjut dari AI akan ditulis ulang, dan token '
          'Anda terpakai lagi. Tindak lanjut yang Anda tambahkan sendiri tetap ada.',
          style: TextStyle(fontSize: 13.sp, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Buat ulang'),
          ),
        ],
      ),
    );

    if (confirmed == true) await _reprocess();
  }

  Future<void> _share() async {
    final detail = _detail;
    if (detail == null) return;

    await SharePlus.instance.share(
      ShareParams(text: detail.shareText, subject: detail.meeting.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return AppPage(
      title: detail?.meeting.title ?? 'Rapat',
      subtitle: detail == null ? null : _subtitle(detail.meeting),
      onRefresh: _load,
      actions: [
        if (detail != null && detail.hasSummaryContent)
          HeaderAction(Iconsax.share, _share),
        if (detail != null &&
            detail.canReprocess &&
            !detail.meeting.isWorking &&
            !detail.meeting.isFailed)
          HeaderAction(Iconsax.refresh, _confirmReprocess),
      ],
      child: _loading
          ? const Loading()
          : detail == null
          ? const EmptyState(
              icon: Iconsax.document_text,
              message: 'Rapat tidak ditemukan.',
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
              children: [
                if (detail.meeting.isWorking) _working(detail),
                if (detail.meeting.isFailed) _failed(detail),
                if (detail.meeting.isReady) ...[
                  _summary(detail),
                  if (detail.insights.isNotEmpty) ...[
                    SizedBox(height: 16.h),
                    _insights(detail),
                  ],
                  // Always shown once the meeting is readable: an empty list
                  // still needs somewhere to add the first item.
                  SizedBox(height: 16.h),
                  _actionItems(detail),
                ],
                if (detail.transcript.isNotEmpty) ...[
                  SizedBox(height: 16.h),
                  _transcript(detail),
                ],
              ],
            ),
    );
  }

  String _subtitle(MeetingItem meeting) {
    final parts = <String>[];

    if (meeting.startedLabel.isNotEmpty) {
      parts.add(meeting.startedLabel);
    }
    if (meeting.durationMinutes > 0) {
      parts.add('${meeting.durationMinutes} menit');
    }

    return parts.join(' · ');
  }

  /// Still transcribing or summarising — say so plainly rather than showing an
  /// empty summary card that reads as a bug.
  Widget _working(MeetingDetail detail) {
    // Past the ceiling the spinner stops: a summary this late is either stuck
    // or the notification will bring the reader back, and either way turning
    // forever tells them nothing.
    if (_waitedTooLong && detail.meeting.status != 'recording') {
      return Container(
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18.r),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Iconsax.clock, size: 18.sp, color: AppColors.warning),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ringkasan belum selesai juga.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Transkrip sudah aman tersimpan. Anda akan diberi tahu '
                    'begitu ringkasannya siap.',
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      height: 1.45,
                      color: AppColors.textMuted,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  GestureDetector(
                    onTap: _retryWaiting,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      'Cek lagi',
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18.w,
            height: 18.w,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(
              detail.meeting.status == 'recording'
                  ? 'Rapat ini masih direkam.'
                  : 'AI sedang menyusun ringkasan. Anda akan diberi tahu saat siap.',
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.45,
                color: AppColors.navy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _failed(MeetingDetail detail) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.warning_2, color: AppColors.danger, size: 19.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.failureReason ?? 'Ringkasan gagal dibuat.',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (detail.canReprocess) ...[
                  SizedBox(height: 12.h),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('meeting-summary-reprocess'),
                      onPressed: _busy ? null : _confirmReprocess,
                      icon: _busy
                          ? SizedBox(
                              width: 16.w,
                              height: 16.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Iconsax.refresh, size: 17.sp),
                      label: Text(
                        _busy ? 'Memproses...' : 'Buat ulang ringkasan',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.45,
                        ),
                        foregroundColor: Colors.white,
                        minimumSize: Size(0, 44.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        textStyle: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The headline output: prose, then the decisions as their own list.
  Widget _summary(MeetingDetail detail) {
    final body = (detail.summary ?? '').trim();

    if (!detail.hasSummaryContent) {
      return Container(
        padding: EdgeInsets.all(18.w),
        decoration: softCard(),
        child: Text(
          'Belum ada ringkasan untuk rapat ini.',
          style: TextStyle(fontSize: 13.sp, color: AppColors.textMuted),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: softCard(),
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
                child: Icon(Iconsax.magicpen, size: 14.sp, color: Colors.white),
              ),
              SizedBox(width: 11.w),
              Text(
                'Ringkasan AI',
                style: TextStyle(
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            SizedBox(height: 14.h),
            Text(
              body,
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.65,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (detail.decisions.isNotEmpty) ...[
            SizedBox(height: 18.h),
            Text(
              'KEPUTUSAN',
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                color: AppColors.textMuted,
              ),
            ),
            SizedBox(height: 10.h),
            for (final decision in detail.decisions)
              Padding(
                padding: EdgeInsets.only(bottom: 9.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 5.h),
                      child: Icon(
                        Iconsax.tick_circle,
                        size: 14.sp,
                        color: AppColors.success,
                      ),
                    ),
                    SizedBox(width: 9.w),
                    Expanded(
                      child: Text(
                        decision,
                        style: TextStyle(
                          fontSize: 12.8.sp,
                          height: 1.55,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// The deep analyses, when somebody has run them on the web.
  ///
  /// Read-only here on purpose: each one spends real tokens, and the request
  /// can run for minutes — far past what a phone request waits for. Generating
  /// stays where the person choosing to pay for it already is.
  Widget _insights(MeetingDetail detail) {
    final icons = <String, IconData>{
      'executive_summary': Iconsax.crown_1,
      'decision_analysis': Iconsax.judge,
      'project_risk': Iconsax.warning_2,
      'sentiment': Iconsax.emoji_happy,
      'follow_up': Iconsax.direct_right,
    };

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: softCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.chart_21, size: 16.sp, color: AppColors.primary),
              SizedBox(width: 9.w),
              Text(
                'Analisis AI',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            'Dibuat dari web. Tekan untuk membuka.',
            style: TextStyle(fontSize: 11.5.sp, color: AppColors.textMuted),
          ),
          SizedBox(height: 14.h),
          for (final insight in detail.insights)
            _insightTile(insight, icons[insight.type] ?? Iconsax.document_text),
        ],
      ),
    );
  }

  Widget _insightTile(MeetingInsight insight, IconData icon) {
    final open = _openInsight == insight.type;
    final bullets = insight.bullets;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  setState(() => _openInsight = open ? null : insight.type),
              child: Padding(
                padding: EdgeInsets.all(13.w),
                child: Row(
                  children: [
                    Icon(icon, size: 16.sp, color: AppColors.primary),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        insight.label,
                        style: TextStyle(
                          fontSize: 12.8.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    Icon(
                      open ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
                      size: 15.sp,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (open)
              Padding(
                padding: EdgeInsets.fromLTRB(13.w, 0, 13.w, 14.h),
                child: bullets.isEmpty
                    ? Text(
                        'Analisis ini belum berisi apa pun.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textMuted,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in bullets)
                            Padding(
                              padding: EdgeInsets.only(bottom: 8.h),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(top: 6.h),
                                    child: Container(
                                      width: 5.w,
                                      height: 5.w,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 9.w),
                                  Expanded(
                                    child: Text(
                                      line,
                                      style: TextStyle(
                                        fontSize: 12.5.sp,
                                        height: 1.55,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
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

  Widget _actionItems(MeetingDetail detail) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: softCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.task_square, size: 16.sp, color: AppColors.primary),
              SizedBox(width: 9.w),
              Text(
                'Tindak Lanjut',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const Spacer(),
              Text(
                '${detail.actionItems.length}',
                style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          if (detail.actionItems.isEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Text(
                'Belum ada tindak lanjut.',
                style: TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted),
              ),
            ),
          for (final item in detail.actionItems)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A generous tap target: these get ticked off one-handed on
                  // the walk out of the room.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _busy ? null : () => _toggle(item),
                    child: Padding(
                      padding: EdgeInsets.only(right: 4.w, bottom: 4.h),
                      child: Icon(
                        item.isDone ? Iconsax.tick_square : Iconsax.stop,
                        size: 18.sp,
                        color: item.isDone
                            ? AppColors.success
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.text,
                          style: TextStyle(
                            fontSize: 12.8.sp,
                            height: 1.5,
                            color: AppColors.textPrimary,
                            decoration: item.isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (item.assignee != null || item.dueDate != null)
                          Padding(
                            padding: EdgeInsets.only(top: 3.h),
                            child: Text(
                              [
                                if (item.assignee != null) item.assignee!,
                                if (item.dueDate != null) item.dueDate!,
                              ].join(' · '),
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          _addItemRow(),
        ],
      ),
    );
  }

  /// Adding one on the spot, for what the summary missed.
  Widget _addItemRow() {
    return Padding(
      padding: EdgeInsets.only(top: 4.h),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _newItem,
              enabled: !_busy,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addItem(),
              style: TextStyle(fontSize: 12.8.sp),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Tambah tindak lanjut…',
                hintStyle: TextStyle(
                  fontSize: 12.5.sp,
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.muted,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 13.w,
                  vertical: 11.h,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(width: 9.w),
          GestureDetector(
            onTap: _busy ? null : _addItem,
            child: Container(
              padding: EdgeInsets.all(11.w),
              decoration: BoxDecoration(
                color: _busy
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : AppColors.primary,
                borderRadius: BorderRadius.circular(11.r),
              ),
              child: Icon(Iconsax.add, size: 16.sp, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Collapsed by default — it is the evidence behind the summary, not the
  /// thing most people came for.
  Widget _transcript(MeetingDetail detail) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: softCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _showTranscript = !_showTranscript),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transkrip',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${detail.transcript.length} ucapan, kata demi kata',
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Named, not a bare arrow: the summary above is what most
                // people came for, so this has to say what opening it gets you.
                Text(
                  _showTranscript ? 'Sembunyikan' : 'Tampilkan',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 4.w),
                Icon(
                  _showTranscript ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
                  size: 15.sp,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
          if (_showTranscript) ...[
            SizedBox(height: 16.h),
            for (var i = 0; i < detail.transcript.length; i++)
              _transcriptEntry(
                detail.transcript[i],
                // A name earns its line when the turn changes. Repeating it on
                // every utterance turned forty lines of a single speaker into a
                // column that reads as "Pembicara 1" forty times over.
                showSpeaker:
                    i == 0 ||
                    detail.transcript[i - 1].speaker !=
                        detail.transcript[i].speaker,
              ),
          ],
        ],
      ),
    );
  }

  /// One line of the minutes: time in the margin, the turn in the column.
  Widget _transcriptEntry(MeetingLine line, {required bool showSpeaker}) {
    return Padding(
      padding: EdgeInsets.only(bottom: showSpeaker ? 6.h : 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSpeaker)
            Padding(
              padding: EdgeInsets.only(left: 42.w, top: 8.h, bottom: 5.h),
              child: Text(
                line.speaker,
                style: TextStyle(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 42.w,
                child: Padding(
                  padding: EdgeInsets.only(top: 2.h),
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
                child: Text(
                  line.text,
                  style: TextStyle(
                    fontSize: 12.8.sp,
                    height: 1.55,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
