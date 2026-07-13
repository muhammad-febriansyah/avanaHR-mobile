import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/dashboard.dart';
import '../../data/models/mss.dart';
import 'mss_member_controller.dart';

class MssMemberView extends GetView<MssMemberController> {
  const MssMemberView({super.key});

  static const _typeColors = {
    'leave': AppColors.success,
    'lembur': AppColors.warning,
    'izin': Color(0xFF9333EA),
    'wfh': Color(0xFF0EA5E9),
    'koreksi': Color(0xFF4F46E5),
    'reimburse': Color(0xFFDB2777),
  };

  @override
  Widget build(BuildContext context) {
    final m = controller.member;
    return AppPage(
      title: m.name,
      subtitle: [m.position, m.department].where((e) => e != null).join(' · '),
      actions: [
        HeaderAction(Iconsax.calendar_edit, () => _openAssign(context)),
      ],
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Loading();
        }
        final d = controller.detail.value;
        return RefreshIndicator(
          onRefresh: controller.load,
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 24.h),
            children: [
              _profile(m),
              SizedBox(height: 16.h),
              if (d != null) ...[
                _sectionTitle('Absensi ${d.attendance.month}'),
                SizedBox(height: 10.h),
                _recap(d.attendance),
                SizedBox(height: 20.h),
                _sectionTitle('Shift Hari Ini'),
                SizedBox(height: 10.h),
                _shift(d.todayShift),
                SizedBox(height: 10.h),
                _assignButton(context),
                SizedBox(height: 20.h),
                _sectionTitle('Request Pending (${d.pending.length})'),
                SizedBox(height: 10.h),
                if (d.pending.isEmpty)
                  _pendingEmpty()
                else
                  ...d.pending.map(_pendingCard),
              ] else
                Padding(
                  padding: EdgeInsets.only(top: 40.h),
                  child: const EmptyState(
                    icon: Iconsax.info_circle,
                    message: 'Gagal memuat detail.',
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _profile(MssTeamMember m) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: m.avatarColor,
            ),
            child: Text(
              m.initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18.sp,
              ),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  [
                    m.position,
                    m.department,
                  ].where((e) => e != null).join(' · '),
                  style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted),
                ),
                if (m.employeeNumber != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    'NIK ${m.employeeNumber}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textMuted,
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

  Widget _recap(AttendanceRecap r) {
    return Row(
      children: [
        _stat('Hadir', '${r.present}', AppColors.success, Iconsax.tick_circle),
        SizedBox(width: 10.w),
        _stat('Telat', '${r.late}', AppColors.warning, Iconsax.clock),
        SizedBox(width: 10.w),
        _stat(
          'Absen',
          '${r.absent}',
          AppColors.destructive,
          Iconsax.close_circle,
        ),
        SizedBox(width: 10.w),
        _stat(
          'Jam',
          r.workHours.toStringAsFixed(0),
          AppColors.primary,
          Iconsax.timer_1,
        ),
      ],
    );
  }

  Widget _stat(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 6.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 32.w,
              height: 32.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9.r),
              ),
              child: Icon(icon, color: color, size: 16.sp),
            ),
            SizedBox(height: 7.h),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
                fontSize: 15.sp,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              label,
              style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shift(TodayShift? shift) {
    final IconData icon;
    final Color color;
    final String title;
    final String sub;

    if (shift == null) {
      icon = Iconsax.calendar_remove;
      color = AppColors.textMuted;
      title = 'Belum dijadwalkan';
      sub = 'Tidak ada jadwal hari ini';
    } else if (shift.isOff) {
      icon = Iconsax.coffee;
      color = const Color(0xFF0EA5E9);
      title = 'Libur';
      sub = 'Tidak ada jadwal kerja';
    } else {
      icon = Iconsax.clock;
      color = const Color(0xFF0D9488);
      title = shift.shiftName ?? 'Shift';
      sub = '${shift.start ?? '--'} – ${shift.end ?? '--'}';
    }

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 21.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                    fontSize: 13.5.sp,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  sub,
                  style: TextStyle(
                    color: color,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingCard(MssPendingItem p) {
    final color = _typeColors[p.type] ?? AppColors.primary;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11.r),
            ),
            child: Icon(Iconsax.document_text, color: color, size: 18.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        p.typeLabel,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  p.detail,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingEmpty() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Icon(Iconsax.tick_circle, size: 20.sp, color: AppColors.success),
          SizedBox(width: 10.w),
          Text(
            'Tidak ada request pending.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
          ),
        ],
      ),
    );
  }

  Widget _assignButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _openAssign(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
          padding: EdgeInsets.symmetric(vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        icon: Icon(Iconsax.calendar_edit, size: 18.sp),
        label: Text(
          'Atur Shift',
          style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      ),
    );
  }

  void _openAssign(BuildContext context) {
    final date = Rxn<DateTime>(DateTime.now());
    // Selected option key: 'off' for a day off, or a shift id as string.
    final selectedKey = RxnString();
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    showAppSheet(
      context,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader('Atur Shift — ${controller.member.name}'),
            SizedBox(height: 16.h),
            Obx(
              () => AppDateField(
                label: 'Tanggal',
                value: date.value,
                onPick: (d) => date.value = d,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Pilih shift',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            SizedBox(height: 8.h),
            Obx(
              () => Column(
                children: [
                  _optionTile(
                    'off',
                    'Libur',
                    'Tidak ada jadwal kerja',
                    selectedKey,
                  ),
                  ...controller.shifts.map(
                    (s) => _optionTile(
                      s.id.toString(),
                      s.name,
                      s.label,
                      selectedKey,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            Obx(
              () => AppSubmitButton(
                loading: controller.assigning.value,
                onPressed: () async {
                  if (date.value == null || selectedKey.value == null) {
                    return;
                  }
                  final key = selectedKey.value!;
                  final ok = await controller.assignShift(
                    date: fmt(date.value!),
                    shiftId: key == 'off' ? null : int.parse(key),
                  );
                  if (ok) Get.back();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(
    String key,
    String title,
    String sub,
    RxnString selectedKey,
  ) {
    final selected = selectedKey.value == key;
    return GestureDetector(
      onTap: () => selectedKey.value = key,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.muted,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Iconsax.tick_circle : Iconsax.record_circle,
              size: 20.sp,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      color: AppColors.textMuted,
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
}
