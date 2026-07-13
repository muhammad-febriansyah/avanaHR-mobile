import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../data/models/mss.dart';
import 'mss_recap_controller.dart';

class MssRecapView extends GetView<MssRecapController> {
  const MssRecapView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Rekap Absensi Tim',
      subtitle: 'Manager Self-Service',
      actions: [
        Obx(() => HeaderAction(
              controller.isExporting.value ? Iconsax.timer_1 : Iconsax.document_download,
              controller.export,
            )),
      ],
      onRefresh: controller.load,
      child: Obx(() {
        if (controller.isLoading.value) {
          return const _Loading();
        }
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          children: [
            _monthBar(),
            SizedBox(height: 14.h),
            _summaryCard(),
            SizedBox(height: 16.h),
            if (controller.rows.isEmpty)
              _empty()
            else
              ...controller.rows.map(_memberCard),
          ],
        );
      }),
    );
  }

  // ---- Month selector -------------------------------------------------------

  Widget _monthBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          _chevron(Iconsax.arrow_left_2, true, controller.prevMonth),
          Expanded(
            child: Obx(() => Text(
                  controller.rangeLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                )),
          ),
          Obx(() => _chevron(
                Iconsax.arrow_right_3,
                controller.canGoNext,
                controller.nextMonth,
              )),
        ],
      ),
    );
  }

  Widget _chevron(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 38.w,
        height: 38.w,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20.sp,
          color: enabled ? AppColors.primary : AppColors.border,
        ),
      ),
    );
  }

  // ---- Summary --------------------------------------------------------------

  Widget _summaryCard() {
    return Obx(() {
      final s = controller.summary.value;
      if (s == null) {
        return const SizedBox.shrink();
      }
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Iconsax.people, size: 16.sp, color: AppColors.primary),
                SizedBox(width: 6.w),
                Text(
                  '${s.members} anggota tim',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const Spacer(),
                Text(
                  '${s.workHours.toStringAsFixed(1)} jam',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _statChip('Hadir', s.present, AppColors.success),
                _statChip('Terlambat', s.late, AppColors.warning),
                _statChip('Alpa', s.absent, AppColors.destructive),
                _statChip('Cuti', s.leave, const Color(0xFF9333EA)),
                _statChip('WFH', s.wfh, const Color(0xFF0EA5E9)),
                _statChip('Libur', s.holiday, AppColors.textMuted),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _statChip(String label, int value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(width: 5.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Member rows ----------------------------------------------------------

  Widget _memberCard(TeamRecapRow m) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: m.avatarColor),
                child: Text(
                  m.initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    if (m.employeeNumber != null) ...[
                      SizedBox(height: 2.h),
                      Text(
                        'NIK ${m.employeeNumber}',
                        style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${m.workHours.toStringAsFixed(1)} jam',
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  if (m.lateMinutes > 0) ...[
                    SizedBox(height: 2.h),
                    Text(
                      'telat ${m.lateMinutes}m',
                      style: TextStyle(fontSize: 11.sp, color: AppColors.warning),
                    ),
                  ],
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _tally('Hadir', m.present, AppColors.success),
              _tally('Telat', m.late, AppColors.warning),
              _tally('Alpa', m.absent, AppColors.destructive),
              _tally('Cuti', m.leave, const Color(0xFF9333EA)),
              _tally('WFH', m.wfh, const Color(0xFF0EA5E9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tally(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: value > 0 ? color : AppColors.textMuted,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(fontSize: 10.5.sp, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ---- States ---------------------------------------------------------------

  Widget _empty() {
    return Padding(
      padding: EdgeInsets.only(top: 60.h),
      child: Column(
        children: [
          Icon(Iconsax.chart_21, size: 56.sp, color: AppColors.border),
          SizedBox(height: 16.h),
          Text(
            'Belum ada data absensi',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Tidak ada anggota tim atau rekaman absensi pada periode ini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
