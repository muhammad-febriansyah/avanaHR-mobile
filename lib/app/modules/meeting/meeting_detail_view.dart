import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
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

  const MeetingDetailView({super.key, required this.meetingId});

  @override
  State<MeetingDetailView> createState() => _MeetingDetailViewState();
}

class _MeetingDetailViewState extends State<MeetingDetailView> {
  final AvanaApi _api = AvanaApi();

  final TextEditingController _newItem = TextEditingController();

  MeetingDetail? _detail;
  bool _loading = true;
  bool _showTranscript = false;
  bool _busy = false;

  /// Which analysis is expanded — one at a time, so the page stays scannable.
  String? _openInsight;

  @override
  void dispose() {
    _newItem.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
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
    }
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
        if (detail != null && detail.canReprocess && !detail.meeting.isWorking)
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

    if (meeting.startedAt != null) {
      parts.add(
        DateFormat('d MMM yyyy · HH:mm', 'id').format(meeting.startedAt!),
      );
    }
    if (meeting.durationMinutes > 0) {
      parts.add('${meeting.durationMinutes} menit');
    }

    return parts.join(' · ');
  }

  /// Still transcribing or summarising — say so plainly rather than showing an
  /// empty summary card that reads as a bug.
  Widget _working(MeetingDetail detail) {
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
            child: Text(
              detail.failureReason ?? 'Ringkasan gagal dibuat.',
              style: TextStyle(
                fontSize: 12.5.sp,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
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
                Icon(
                  Iconsax.document_text,
                  size: 16.sp,
                  color: AppColors.primary,
                ),
                SizedBox(width: 9.w),
                Text(
                  'Transkrip',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                SizedBox(width: 7.w),
                Text(
                  '${detail.transcript.length} ucapan',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                Icon(
                  _showTranscript ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
                  size: 16.sp,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
          if (_showTranscript) ...[
            SizedBox(height: 16.h),
            for (final line in detail.transcript)
              Padding(
                padding: EdgeInsets.only(bottom: 14.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 42.w,
                      child: Text(
                        line.timecode,
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          color: AppColors.textMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.speaker,
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            line.text,
                            style: TextStyle(
                              fontSize: 12.8.sp,
                              height: 1.55,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
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
}
