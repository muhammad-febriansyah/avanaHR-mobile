import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/meeting.dart';
import 'meeting_controller.dart';
import 'meeting_detail_view.dart';

/// AI Recorder: the meetings this person may read, and the button that starts
/// a new recording.
class MeetingView extends GetView<MeetingController> {
  const MeetingView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'AI Recorder',
      subtitle: 'Rekam rapat, dapatkan transkrip & ringkasan',
      onRefresh: controller.load,
      child: Obx(() {
        if (controller.isLoading.value) return const Loading();

        return ListView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
          children: [
            _recordCard(context),
            SizedBox(height: 18.h),
            SectionTitle(
              'Rapat Terekam',
              trailing: Text(
                '${controller.meetings.length}',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 10.h),
            if (controller.meetings.isEmpty)
              const EmptyState(
                icon: Iconsax.microphone_2,
                message:
                    'Belum ada rapat yang direkam.\nTekan tombol di atas untuk mulai.',
              )
            else
              ...controller.meetings.map(_tile),
          ],
        );
      }),
    );
  }

  /// The one action this screen exists for, or the reason it cannot be taken.
  Widget _recordCard(BuildContext context) {
    final status = controller.status.value;

    if (!status.available) {
      return _notice(
        icon: Iconsax.warning_2,
        tone: AppColors.warning,
        title: 'Perekaman belum aktif',
        body:
            'Admin perlu mengaktifkan layanan transkripsi terlebih dahulu di '
            'Pengaturan AI.',
      );
    }

    if (!status.canRecord) {
      return _notice(
        icon: Iconsax.empty_wallet,
        tone: AppColors.danger,
        title: 'Token tidak mencukupi',
        body: status.blockedMessage ?? 'Token AI Anda sudah habis bulan ini.',
      );
    }

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryHover],
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(11.w),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  Iconsax.microphone_2,
                  color: Colors.white,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 13.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rekam Rapat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Transkrip otomatis per pembicara',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: Obx(
              () => ElevatedButton.icon(
                onPressed: controller.isStarting.value
                    ? null
                    : () => _startSheet(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 13.h),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13.r),
                  ),
                ),
                icon: controller.isStarting.value
                    ? SizedBox(
                        width: 15.w,
                        height: 15.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      )
                    : Icon(Iconsax.record_circle, size: 18.sp),
                label: Text(
                  'Mulai Rekam',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
          ),
          if (status.tokenCostPerMinute != null) ...[
            SizedBox(height: 10.h),
            Text(
              '± ${NumberFormat.decimalPattern('id').format(status.tokenCostPerMinute)} token / menit'
              '${status.maxMinutes != null ? ' · maksimal ${status.maxMinutes} menit' : ''}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11.sp,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _notice({
    required IconData icon,
    required Color tone,
    required String title,
    required String body,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 20.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5.sp,
                    color: AppColors.navy,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    height: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(MeetingItem meeting) {
    final tone = switch (meeting.status) {
      'recording' => AppColors.danger,
      'processing' => AppColors.warning,
      'failed' => AppColors.textMuted,
      _ => AppColors.success,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: GestureDetector(
        onTap: () => Get.to(() => MeetingDetailView(meetingId: meeting.id)),
        child: Container(
          padding: EdgeInsets.all(15.w),
          decoration: softCard(),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(11.w),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13.r),
                ),
                child: Icon(
                  meeting.isWorking
                      ? Iconsax.clock
                      : (meeting.isFailed
                            ? Iconsax.warning_2
                            : Iconsax.document_text),
                  color: tone,
                  size: 17.sp,
                ),
              ),
              SizedBox(width: 13.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meeting.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5.sp,
                        color: AppColors.navy,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      _subtitle(meeting),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  meeting.statusLabel,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                    color: tone,
                  ),
                ),
              ),
            ],
          ),
        ),
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
    if (meeting.participants.isNotEmpty) {
      parts.add('${meeting.participants.length} peserta');
    }

    return parts.isEmpty ? 'Belum ada detail' : parts.join(' · ');
  }

  /// Ask for the title before the microphone opens — a recording without one
  /// is unfindable a week later.
  Future<void> _startSheet(BuildContext context) async {
    final titleField = TextEditingController();
    final locationField = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 26.h),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              SizedBox(height: 18.h),
              Text(
                'Rapat Baru',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Beri judul supaya mudah dicari nanti.',
                style: TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted),
              ),
              SizedBox(height: 18.h),
              _field(titleField, 'Judul rapat', 'mis. Weekly Sync Produk'),
              SizedBox(height: 12.h),
              _field(
                locationField,
                'Lokasi (opsional)',
                'mis. Ruang Meeting Lt. 3',
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final title = titleField.text.trim();
                    if (title.isEmpty) return;

                    Navigator.of(sheetContext).pop();
                    controller.start(
                      title: title,
                      location: locationField.text.trim(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13.r),
                    ),
                  ),
                  icon: Icon(Iconsax.record_circle, size: 18.sp),
                  label: Text(
                    'Mulai Rekam',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
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

  Widget _field(TextEditingController field, String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 7.h),
        TextField(
          controller: field,
          style: TextStyle(fontSize: 13.5.sp),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13.sp, color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.muted,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14.w,
              vertical: 13.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
