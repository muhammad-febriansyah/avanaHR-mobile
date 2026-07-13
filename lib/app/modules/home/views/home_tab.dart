import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../data/models/ess_models.dart';
import '../../../routes/app_pages.dart';
import '../../main/main_controller.dart';
import '../controllers/home_controller.dart';

/// Beranda tab — attendance-first home. Blue location/welcome header, a white
/// attendance hero card (work-mode toggle, live clock, clock-in/out, worked
/// hours), monthly attendance stats, and quick-request + menu below.
class HomeTab extends GetView<HomeController> {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: RefreshIndicator(
          onRefresh: controller.refreshAll,
          color: AppColors.primary,
          backgroundColor: Colors.white,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [_header(), _sheet(context)],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _header() {
    return Container(
      decoration: const BoxDecoration(
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
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 16.w, 78.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44.w,
                        height: 44.w,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Iconsax.location,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Lokasi',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 11.sp,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Obx(() {
                                  final active =
                                      !controller.locating.value &&
                                      controller.userAddress.value.isNotEmpty;
                                  return Container(
                                    width: 6.w,
                                    height: 6.w,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? AppColors.success
                                          : AppColors.warning,
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                }),
                              ],
                            ),
                            SizedBox(height: 2.h),
                            Obx(() {
                              final addr = controller.userAddress.value;
                              final label = addr.isNotEmpty
                                  ? addr
                                  : (controller.locating.value
                                        ? 'Mendeteksi lokasi…'
                                        : 'Lokasi tidak tersedia');
                              return Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      Obx(
                        () => _iconButton(
                          Iconsax.notification,
                          () => Get.toNamed(Routes.NOTIFICATION),
                          badge: controller.unread.value,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 22.h),
                  Obx(
                    () => Text(
                      'Selamat datang, ${controller.name.isEmpty ? '—' : controller.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
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

  Widget _iconButton(IconData icon, VoidCallback onTap, {int badge = 0}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100.r),
      child: Stack(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20.sp),
          ),
          if (badge > 0)
            Positioned(
              right: 3.w,
              top: 3.h,
              child: Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: AppColors.destructive,
                  shape: BoxShape.circle,
                ),
                constraints: BoxConstraints(minWidth: 15.w, minHeight: 15.w),
                child: Text(
                  '$badge',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Sheet ─────────────────────────────────────────────────────────────────

  Widget _sheet(BuildContext context) {
    // How far the attendance card overhangs upward into the blue header, so it
    // straddles the blue/white seam. Also acts as the card→content gap below,
    // since Transform.translate doesn't shrink the reserved layout slot.
    final poke = 44.h;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 0.72.sh),
      decoration: const BoxDecoration(color: AppColors.background),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16.w,
          0,
          16.w,
          24.h + AppPage.bottomNavClearance(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Attendance hero card straddles the blue header / white sheet seam.
            Transform.translate(offset: Offset(0, -poke), child: _heroCard()),
            _managerBanner(),
            _monthlyHeader(),
            SizedBox(height: 12.h),
            _monthlyStats(),
            SizedBox(height: 14.h),
            _requestButton(),
            SizedBox(height: 26.h),
            _sectionHeader('Menu Cepat'),
            SizedBox(height: 14.h),
            _MenuCarousel(_allActions()),
            SizedBox(height: 26.h),
            _sectionHeader(
              'Pengumuman Terbaru',
              onTap: () => Get.find<MainController>().changeTab(3),
            ),
            SizedBox(height: 12.h),
            _announcements(),
          ],
        ),
      ),
    );
  }

  // ── Attendance hero card ────────────────────────────────────────────────────

  Widget _heroCard() {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _shiftBadge(),
              const Spacer(),
              Icon(Iconsax.calendar_1, size: 13.sp, color: AppColors.textMuted),
              SizedBox(width: 5.w),
              Flexible(
                child: Text(
                  controller.todayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Obx(() {
            final t = controller.today.value;
            final canIn = t?.canClockIn ?? true;
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canIn ? 'Belum absen masuk' : 'Sedang bekerja',
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      const _LiveClock(),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                SizedBox(
                  height: 46.h,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canIn
                          ? AppColors.primary
                          : AppColors.destructive,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      // Override the theme's full-width Size.fromHeight so the
                      // button sizes to its content inside the Row (an infinite
                      // width min in an unbounded Row axis would crash layout).
                      minimumSize: Size(0, 46.h),
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                    ),
                    onPressed: () => Get.find<MainController>().changeTab(
                      MainController.attendanceTab,
                    ),
                    icon: Icon(
                      canIn ? Iconsax.login_1 : Iconsax.logout_1,
                      size: 18.sp,
                    ),
                    label: Text(
                      canIn ? 'Masuk' : 'Keluar',
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Divider(height: 1, color: AppColors.border),
          ),
          Obx(() {
            final t = controller.today.value;
            return Row(
              children: [
                _clockCol(
                  Iconsax.login_1,
                  'Masuk',
                  t?.clockIn ?? '--:--',
                  AppColors.success,
                ),
                _clockCol(
                  Iconsax.logout_1,
                  'Keluar',
                  t?.clockOut ?? '--:--',
                  AppColors.destructive,
                ),
                _clockCol(
                  Iconsax.clock,
                  'Jam Kerja',
                  _hms(t?.workMinutes ?? 0),
                  AppColors.primary,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _shiftBadge() {
    return Obx(() {
      final shift = controller.summary.value?.todayShift;
      final label = shift?.isOff == true
          ? 'HARI LIBUR'
          : (shift?.shiftName?.toUpperCase() ?? 'SHIFT UMUM');
      final color = shift?.isOff == true
          ? AppColors.warning
          : AppColors.success;
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      );
    });
  }

  Widget _clockCol(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: color, size: 16.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              fontSize: 13.sp,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
          ),
        ],
      ),
    );
  }

  /// Worked minutes → HH:mm:ss (seconds fixed at 00, mirrors the reference).
  String _hms(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  // ── Monthly attendance ──────────────────────────────────────────────────────

  Widget _monthlyHeader() {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MEI',
      'JUN',
      'JUL',
      'AGU',
      'SEP',
      'OKT',
      'NOV',
      'DES',
    ];
    final month = months[DateTime.now().month - 1];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Absensi Bulan Ini',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                month,
                style: TextStyle(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 6.w),
              Icon(Iconsax.calendar_1, size: 13.sp, color: AppColors.primary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _monthlyStats() {
    return Obx(() {
      final s = controller.summary.value;
      return Row(
        children: [
          Expanded(
            child: _statCard('Hadir', s?.presentDays, AppColors.success),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _statCard('Absen', s?.absentDays, AppColors.destructive),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _statCard('Terlambat', s?.lateDays, AppColors.warning),
          ),
        ],
      );
    });
  }

  Widget _statCard(String label, int? value, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          children: [
            Container(height: 4.h, color: color),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
              child: Column(
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    value == null ? '—' : value.toString().padLeft(2, '0'),
                    style: TextStyle(
                      color: color,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
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

  Widget _requestButton() {
    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide.none,
          backgroundColor: AppColors.primaryLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        onPressed: _openRequestSheet,
        icon: Icon(Iconsax.add, size: 20.sp),
        label: Text(
          'Ajukan',
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  void _openRequestSheet() {
    final items = <_Action>[
      _Action(
        'Cuti',
        Iconsax.sun_1,
        AppColors.success,
        () => Get.toNamed(Routes.LEAVE),
      ),
      _Action(
        'Izin',
        Iconsax.calendar_remove,
        const Color(0xFF9333EA),
        () => Get.toNamed(Routes.PERMISSION),
      ),
      _Action(
        'Lembur',
        Iconsax.timer_1,
        AppColors.warning,
        () => Get.toNamed(Routes.OVERTIME),
      ),
      _Action(
        'WFH',
        Iconsax.house,
        AppColors.info,
        () => Get.toNamed(Routes.WFH),
      ),
      _Action(
        'Reimburse',
        Iconsax.wallet_money,
        const Color(0xFFDB2777),
        () => Get.toNamed(Routes.REIMBURSEMENT),
      ),
      _Action(
        'Koreksi',
        Iconsax.clock,
        const Color(0xFF4F46E5),
        () => Get.toNamed(Routes.ATTENDANCE_CORRECTION),
      ),
      _Action(
        'Tukar Shift',
        Iconsax.arrow_swap_horizontal,
        const Color(0xFF0D9488),
        () => Get.toNamed(Routes.SHIFT_SWAP),
      ),
    ];
    showAppSheet(
      Get.context!,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 28.h),
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
                  borderRadius: BorderRadius.circular(100.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Ajukan Permintaan',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
                fontSize: 15.sp,
              ),
            ),
            SizedBox(height: 14.h),
            Wrap(
              spacing: 12.w,
              runSpacing: 14.h,
              children: items.map((a) {
                return SizedBox(
                  width: (Get.width - 40.w - 24.w) / 3,
                  child: GestureDetector(
                    onTap: () {
                      Get.back();
                      a.onTap();
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 52.w,
                          height: 52.w,
                          decoration: BoxDecoration(
                            color: a.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Icon(a.icon, color: a.color, size: 24.sp),
                        ),
                        SizedBox(height: 7.h),
                        Text(
                          a.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Manager banner ──────────────────────────────────────────────────────────

  Widget _managerBanner() {
    return Obx(() {
      if (!controller.isManager) {
        return const SizedBox.shrink();
      }
      final pending = controller.pendingApprovals.value;
      final team = controller.teamCount.value;
      return Container(
        margin: EdgeInsets.only(bottom: 14.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF4F46E5),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42.w,
                  height: 42.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(Iconsax.people, color: Colors.white, size: 21.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mode Manajer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '$team anggota tim${pending > 0 ? ' · $pending menunggu persetujuan' : ' · semua permintaan beres'}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11.5.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                if (pending > 0)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$pending',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: _managerBtn(
                    Iconsax.task_square,
                    'Persetujuan',
                    () => Get.toNamed(Routes.MSS),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _managerBtn(
                    Iconsax.chart_2,
                    'Rekap Tim',
                    () => Get.toNamed(Routes.MSS_RECAP),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _managerBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 17.sp),
            SizedBox(width: 7.w),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sections ────────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, {VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        if (onTap != null)
          InkWell(
            onTap: onTap,
            child: Text(
              'Lihat semua',
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  List<_Action> _allActions() {
    return [
      _Action(
        'Perasaan',
        Iconsax.emoji_happy,
        const Color(0xFF2547F9),
        controller.openMoodDialog,
      ),
      _Action(
        'Slip Gaji',
        Iconsax.receipt_2,
        const Color(0xFF0891B2),
        () => Get.toNamed(Routes.PAYSLIP),
      ),
      _Action(
        'Cuti',
        Iconsax.sun_1,
        const Color(0xFF22C55E),
        () => Get.toNamed(Routes.LEAVE),
      ),
      _Action(
        'Jadwal',
        Iconsax.calendar_1,
        const Color(0xFF0D9488),
        () => Get.toNamed(Routes.SCHEDULE),
      ),
      _Action(
        'Dasbor',
        Iconsax.category,
        const Color(0xFF7C3AED),
        () => Get.find<MainController>().changeTab(1),
      ),
      _Action(
        'Lembur',
        Iconsax.timer_1,
        const Color(0xFFF59E0B),
        () => Get.toNamed(Routes.OVERTIME),
      ),
      _Action(
        'Izin',
        Iconsax.calendar_remove,
        const Color(0xFF9333EA),
        () => Get.toNamed(Routes.PERMISSION),
      ),
      _Action(
        'Reimburse',
        Iconsax.wallet_money,
        const Color(0xFFDB2777),
        () => Get.toNamed(Routes.REIMBURSEMENT),
      ),
      _Action(
        'WFH',
        Iconsax.house,
        const Color(0xFF0EA5E9),
        () => Get.toNamed(Routes.WFH),
      ),
      _Action(
        'Koreksi',
        Iconsax.clock,
        const Color(0xFF4F46E5),
        () => Get.toNamed(Routes.ATTENDANCE_CORRECTION),
      ),
      _Action(
        'Dokumen',
        Iconsax.document_text,
        const Color(0xFF9333EA),
        () => Get.toNamed(Routes.DOKUMEN),
      ),
      _Action(
        'Kunjungan',
        Iconsax.location,
        const Color(0xFFE11D48),
        () => Get.toNamed(Routes.VISITING),
      ),
      _Action(
        'Tukar Shift',
        Iconsax.arrow_swap_horizontal,
        const Color(0xFF0D9488),
        () => Get.toNamed(Routes.SHIFT_SWAP),
      ),
      _Action(
        'Pengumuman',
        Iconsax.volume_high,
        const Color(0xFFEA580C),
        () => Get.find<MainController>().changeTab(3),
      ),
    ];
  }

  Widget _announcements() {
    return Obx(() {
      final items = controller.announcements;
      if (items.isEmpty) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
          decoration: BoxDecoration(
            color: AppColors.muted,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            children: [
              Icon(
                Iconsax.volume_high,
                size: 20.sp,
                color: AppColors.textMuted,
              ),
              SizedBox(width: 10.w),
              Text(
                'Belum ada pengumuman.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
              ),
            ],
          ),
        );
      }
      return Column(children: items.map(_announcementCard).toList());
    });
  }

  Widget _announcementCard(AnnouncementItem a) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11.r),
            ),
            child: Icon(
              a.pinned ? Iconsax.paperclip2 : Iconsax.volume_high,
              color: AppColors.primary,
              size: 19.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                    fontSize: 13.5.sp,
                  ),
                ),
                if (a.body != null && a.body!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 2.h),
                    child: Text(
                      a.body!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (a.publishedAt != null)
            Text(
              a.publishedAt!.split('T').first,
              style: TextStyle(color: AppColors.textMuted, fontSize: 10.5.sp),
            ),
        ],
      ),
    );
  }
}

/// Live ticking clock (hh:mm:ss AM/PM) for the attendance hero card.
class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _text {
    final h24 = _now.hour;
    final h = (h24 % 12 == 0 ? 12 : h24 % 12).toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    final ap = h24 < 12 ? 'AM' : 'PM';
    return '$h:$m:$s $ap';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _text,
      style: TextStyle(
        fontSize: 22.sp,
        fontWeight: FontWeight.w800,
        color: AppColors.navy,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _Action {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _Action(this.label, this.icon, this.color, this.onTap);
}

/// Quick-menu carousel: swipeable pages of a 4×2 icon grid with page dots.
class _MenuCarousel extends StatefulWidget {
  final List<_Action> actions;
  const _MenuCarousel(this.actions);

  @override
  State<_MenuCarousel> createState() => _MenuCarouselState();
}

class _MenuCarouselState extends State<_MenuCarousel> {
  static const _perPage = 8; // 4 columns × 2 rows
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<List<_Action>> get _pages {
    final pages = <List<_Action>>[];
    for (var i = 0; i < widget.actions.length; i += _perPage) {
      pages.add(
        widget.actions.sublist(
          i,
          (i + _perPage).clamp(0, widget.actions.length),
        ),
      );
    }
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;

    return Column(
      children: [
        SizedBox(
          height: 186.h,
          child: PageView.builder(
            controller: _controller,
            itemCount: pages.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, p) => _grid(pages[p]),
          ),
        ),
        if (pages.length > 1) ...[
          SizedBox(height: 14.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pages.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                width: active ? 20.w : 6.w,
                height: 6.w,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(3.r),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _grid(List<_Action> items) {
    final rows = <List<_Action>>[];
    for (var i = 0; i < items.length; i += 4) {
      rows.add(items.sublist(i, (i + 4).clamp(0, items.length)));
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var r = 0; r < rows.length; r++)
          Padding(
            padding: EdgeInsets.only(bottom: r == rows.length - 1 ? 0 : 18.h),
            child: Row(
              children: List.generate(
                4,
                (i) => i < rows[r].length
                    ? Expanded(child: _tile(rows[r][i]))
                    : const Expanded(child: SizedBox.shrink()),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tile(_Action a) {
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: a.onTap,
      child: Column(
        children: [
          Container(
            width: 54.w,
            height: 54.w,
            decoration: BoxDecoration(
              color: a.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(a.icon, color: a.color, size: 25.sp),
          ),
          SizedBox(height: 7.h),
          Text(
            a.label,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
              fontSize: 11.sp,
            ),
          ),
        ],
      ),
    );
  }
}
