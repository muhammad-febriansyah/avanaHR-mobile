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
      child: Obx(() {
        if (controller.isLoading.value) return const Loading();

        return Column(
          children: [
            _tabs(),
            Expanded(
              child: controller.tab.value == 0
                  ? _recordTab(context)
                  : _archiveTab(context),
            ),
          ],
        );
      }),
    );
  }

  /// Two rooms, not one long page: start a recording, or go through the ones
  /// already made.
  Widget _tabs() {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _tab(index: 0, label: 'Rekam'),
          _tab(index: 1, label: 'Arsip', count: controller.meetings.length),
        ],
      ),
    );
  }

  Widget _tab({required int index, required String label, int? count}) {
    final active = controller.tab.value == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => controller.tab.value = index,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.h),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? AppColors.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5.sp,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active ? AppColors.primary : AppColors.textMuted,
                ),
              ),
              if (count != null && count > 0) ...[
                SizedBox(width: 6.w),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? AppColors.primary.withValues(alpha: 0.7)
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.load,
      color: AppColors.primary,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 28.h),
        children: [_recordCard(context)],
      ),
    );
  }

  /// The archive: search the server, narrow by state, then the register itself.
  Widget _archiveTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
          child: Column(
            children: [
              _searchField(),
              SizedBox(height: 12.h),
              _statusFilters(),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.load,
            color: AppColors.primary,
            child: Obx(() {
              if (controller.isFiltering.value) return const Loading();

              final visible = controller.visible;

              if (visible.isEmpty) {
                return ListView(
                  padding: EdgeInsets.fromLTRB(16.w, 30.h, 16.w, 28.h),
                  children: [
                    EmptyState(
                      icon: Iconsax.document_text,
                      message: controller.meetings.isEmpty
                          ? 'Belum ada rapat yang direkam.\nBuka tab Rekam untuk mulai.'
                          : 'Tidak ada rapat yang cocok dengan\npencarian atau filter ini.',
                    ),
                  ],
                );
              }

              return ListView.builder(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 28.h),
                itemCount: visible.length,
                itemBuilder: (_, i) => _tile(visible[i]),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _searchField() {
    return TextField(
      onSubmitted: controller.applySearch,
      textInputAction: TextInputAction.search,
      style: TextStyle(fontSize: 13.sp),
      decoration: InputDecoration(
        hintText: 'Cari judul rapat…',
        hintStyle: TextStyle(fontSize: 13.sp, color: AppColors.textMuted),
        prefixIcon: Icon(
          Iconsax.search_normal_1,
          size: 17.sp,
          color: AppColors.textMuted,
        ),
        filled: true,
        fillColor: AppColors.muted,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _statusFilters() {
    return Obx(
      () => Row(
        children: [
          for (final filter in MeetingController.filters) ...[
            _filterChip(filter.label, filter.key),
            if (filter != MeetingController.filters.last) SizedBox(width: 8.w),
          ],
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? key) {
    final active = controller.statusFilter.value == key;
    final count = controller.countOf(key);

    return Expanded(
      child: GestureDetector(
        onTap: () => controller.statusFilter.value = key,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9.r),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            count > 0 ? '$label $count' : label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppColors.textMuted,
            ),
          ),
        ),
      ),
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

    // A blank page waiting to be written on, rather than a promotional tile:
    // the thing this feature produces is a set of minutes, and the screen may
    // as well say so before a word has been spoken.
    return Container(
      padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 18.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notulen rapat berikutnya',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 5.h),
          Text(
            'Letakkan ponsel di tengah meja. Setiap ucapan dicatat lengkap '
            'dengan waktu dan pembicaranya, lalu diringkas begitu rapat usai.',
            style: TextStyle(
              fontSize: 12.5.sp,
              height: 1.55,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 18.h),
          SizedBox(
            width: double.infinity,
            child: Obx(
              () => ElevatedButton.icon(
                onPressed: controller.isStarting.value
                    ? null
                    : () => _startSheet(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.6,
                  ),
                  disabledForegroundColor: Colors.white70,
                  padding: EdgeInsets.symmetric(vertical: 15.h),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                icon: controller.isStarting.value
                    ? SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Icon(Iconsax.record_circle, size: 18.sp),
                label: Text(
                  controller.isStarting.value
                      ? 'Menyiapkan…'
                      : 'Mulai Merekam Rapat',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
          ),
          if (status.tokenCostPerMinute != null) ...[
            SizedBox(height: 12.h),
            Text(
              '± ${NumberFormat.decimalPattern('id').format(status.tokenCostPerMinute)} token per menit bicara'
              '${status.maxMinutes != null ? ' · batas ${status.maxMinutes} menit' : ' · berhenti sendiri bila token habis atau ruangan sunyi'}',
              style: TextStyle(
                fontSize: 11.sp,
                height: 1.45,
                color: AppColors.textMuted,
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

    // An entry in a register rather than a card: date in the margin, title on
    // the line, and the state said in words at the end of it.
    return GestureDetector(
      onTap: () => Get.to(() => MeetingDetailView(meetingId: meeting.id)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 46.w,
              child: Text(
                meeting.dayLabel,
                style: TextStyle(
                  fontSize: 11.sp,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
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
            SizedBox(width: 10.w),
            Padding(
              padding: EdgeInsets.only(top: 1.h),
              child: Text(
                meeting.statusLabel,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: tone,
                ),
              ),
            ),
          ],
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
