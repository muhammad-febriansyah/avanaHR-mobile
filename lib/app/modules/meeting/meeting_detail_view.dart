import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

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

  MeetingDetail? _detail;
  bool _loading = true;
  bool _showTranscript = false;

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

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return AppPage(
      title: detail?.meeting.title ?? 'Rapat',
      subtitle: detail == null ? null : _subtitle(detail.meeting),
      onRefresh: _load,
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
                  if (detail.actionItems.isNotEmpty) ...[
                    SizedBox(height: 16.h),
                    _actionItems(detail),
                  ],
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
      parts.add(DateFormat('d MMM yyyy · HH:mm', 'id').format(meeting.startedAt!));
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

  /// The headline output: prose, then the decisions pulled out as their own list.
  Widget _summary(MeetingDetail detail) {
    final parsed = detail.parsedSummary;

    if (parsed.body.isEmpty && parsed.decisions.isEmpty) {
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
          if (parsed.body.isNotEmpty) ...[
            SizedBox(height: 14.h),
            Text(
              parsed.body,
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.65,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (parsed.decisions.isNotEmpty) ...[
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
            for (final decision in parsed.decisions)
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
          for (final item in detail.actionItems)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.isDone ? Iconsax.tick_square : Iconsax.stop,
                    size: 16.sp,
                    color: item.isDone
                        ? AppColors.success
                        : AppColors.textMuted,
                  ),
                  SizedBox(width: 10.w),
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
                  style: TextStyle(fontSize: 11.5.sp, color: AppColors.textMuted),
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
