import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formats.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/tenant_brand_row.dart';
import '../../../data/models/attendance.dart';
import '../../../data/models/dashboard.dart';
import '../../../data/models/ess_models.dart';
import '../../../data/models/user.dart';
import '../../../data/providers/avana_api.dart';
import '../../../routes/app_pages.dart';
import '../../attendance/attendance_controller.dart';
import '../../main/main_controller.dart';
import '../controllers/home_controller.dart';

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

  Widget _header() {
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
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
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
            // Lift the rest up so it doesn't sit a full `poke` gap below the
            // card (Transform.translate leaves the card's original slot), while
            // keeping a small, even gap under it.
            Transform.translate(
              offset: Offset(0, -(poke - 14.h)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _managerBanner(),
                  _birthdays(),
                  // ── Monthly attendance ──
                  _monthlyHeader(),
                  SizedBox(height: 14.h),
                  _monthlyStats(),
                  SizedBox(height: 28.h),
                  // ── Quick menu ──
                  _sectionHeader('Menu Cepat'),
                  SizedBox(height: 14.h),
                  Container(
                    padding: EdgeInsets.fromLTRB(6.w, 16.h, 6.w, 14.h),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    // Reactive: the tiles come from the signed-in user, which a
                    // pull-to-refresh reloads. Without Obx the carousel kept
                    // whatever it was built with, so an admin's change only
                    // showed after the app was killed and reopened.
                    child: Obx(() {
                      final actions = _allActions();

                      // Re-key on the set itself so the carousel starts from
                      // page one rather than a page that no longer exists.
                      return _MenuCarousel(
                        actions,
                        key: ValueKey(
                          actions.map((a) => a.label).join('|'),
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 28.h),
                  // ── Announcements ──
                  _sectionHeader(
                    'Pengumuman Terbaru',
                    onTap: () => Get.find<MainController>().changeTab(3),
                  ),
                  SizedBox(height: 14.h),
                  _announcements(),
                ],
              ),
            ),
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
          const TenantBrandRow(),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 14.h),
            child: Divider(height: 1, color: AppColors.border),
          ),
          Row(
            children: [
              _shiftBadge(),
              const Spacer(),
              Icon(Iconsax.calendar_1, size: 13.sp, color: AppColors.textMuted),
              SizedBox(width: 5.w),
              Flexible(
                child: Text(
                  controller.todayShort,
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
            final done = t?.isDone ?? false;
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        done
                            ? 'Absensi hari ini selesai'
                            : canIn
                            ? 'Belum absen masuk'
                            : 'Sedang bekerja',
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
                      disabledBackgroundColor: AppColors.textMuted.withValues(
                        alpha: 0.3,
                      ),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: Size(0, 46.h),
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                    ),
                    onPressed: done
                        ? null
                        : () => Get.find<MainController>().changeTab(
                            MainController.attendanceTab,
                          ),
                    icon: Icon(
                      done
                          ? Iconsax.tick_circle
                          : canIn
                          ? Iconsax.login_1
                          : Iconsax.logout_1,
                      size: 18.sp,
                    ),
                    label: Text(
                      done
                          ? 'Selesai'
                          : canIn
                          ? 'Masuk'
                          : 'Keluar',
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
                  _clockValueText(t?.clockIn ?? '--:--'),
                  AppColors.success,
                ),
                _clockCol(
                  Iconsax.logout_1,
                  'Keluar',
                  _clockValueText(t?.clockOut ?? '--:--'),
                  AppColors.destructive,
                ),
                // Jam Kerja disembunyikan sementara — restore bila sudah siap.
                // _clockCol(
                //   Iconsax.clock,
                //   'Jam Kerja',
                //   const _LiveWorkedHours(),
                //   AppColors.primary,
                // ),
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
      // On a rotation the name alone does not answer "what time do I start
      // today", so the hours ride along with it.
      final hours = shift != null && shift.isOff == false && shift.start != null
          ? ' · ${shift.hours}'
          : '';
      final label = shift?.isOff == true
          ? 'HARI LIBUR'
          : '${shift?.shiftName?.toUpperCase() ?? 'SHIFT UMUM'}$hours';
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

  Widget _clockCol(IconData icon, String label, Widget value, Color color) {
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
          value,
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

  /// Bold value text for a clock column (tabular figures for stable width).
  Widget _clockValueText(String v) {
    return Text(
      v,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        color: AppColors.navy,
        fontSize: 13.sp,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  // ── Monthly attendance ──────────────────────────────────────────────────────

  Widget _monthlyHeader() {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
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
      final present = s?.presentDays ?? 0;
      final absent = s?.absentDays ?? 0;
      final late = s?.lateDays ?? 0;
      // Late days still count as present, so split "present" into on-time + late
      // for a truthful part-to-whole (on-time + late + absent = work days).
      final onTime = (present - late).clamp(0, present);
      final total = present + absent;
      final centerText = total == 0
          ? '—'
          : '${((present / total) * 100).round()}%';

      return Container(
        padding: EdgeInsets.fromLTRB(18.w, 18.h, 20.w, 18.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 116.w,
              height: 116.w,
              child: _AttendanceDonut(
                segments: [
                  (onTime.toDouble(), AppColors.success),
                  (late.toDouble(), AppColors.warning),
                  (absent.toDouble(), AppColors.destructive),
                ],
                centerText: centerText,
                centerLabel: 'Hadir',
              ),
            ),
            SizedBox(width: 20.w),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legendRow(AppColors.success, 'Tepat Waktu', onTime),
                  SizedBox(height: 12.h),
                  _legendRow(AppColors.warning, 'Terlambat', late),
                  SizedBox(height: 12.h),
                  _legendRow(AppColors.destructive, 'Absen', absent),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _legendRow(Color color, String label, int count) {
    return Row(
      children: [
        Container(
          width: 10.w,
          height: 10.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          count.toString().padLeft(2, '0'),
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  // ── Birthdays ───────────────────────────────────────────────────────────────

  /// Today's birthdays inside the employee's own company. Renders nothing on
  /// the vast majority of days, which is why it sits above the monthly stats:
  /// when it does appear it is the one thing on the page that expires today.
  Widget _birthdays() {
    return Obx(() {
      final summary = controller.summary.value;
      final people = summary?.birthdays ?? const <BirthdayPerson>[];

      if (people.isEmpty) {
        return const SizedBox.shrink();
      }

      final total = summary?.birthdaysTotal ?? people.length;

      return Padding(
        padding: EdgeInsets.only(bottom: 28.h),
        child: Builder(
          builder: (context) => _BirthdayBanner(
            people,
            total: total,
            // Three names fit on the banner; anyone past that is only reachable
            // through the sheet, so the tap only exists once it has a purpose.
            onTap: total > _BirthdayBanner.maxFaces
                ? () => showAppSheet(
                    context,
                    scrollable: true,
                    child: const _BirthdaySheet(),
                  )
                : null,
          ),
        ),
      );
    });
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
        margin: EdgeInsets.only(bottom: 28.h),
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

  /// Quick-menu order, grouped by the job the employee came to do rather than
  /// by when each screen was built. The carousel fills left-to-right, so the
  /// first page holds the things people open weekly (leave, permits, overtime)
  /// and the tail holds the occasional ones (documents, SOP, mood).
  List<_Action> _allActions() {
    final tiles = controller.auth.user.value?.menu ?? const [];

    // Nothing from the server — an older backend, or a login that predates the
    // field — so fall back to the list this build ships with.
    if (tiles.isEmpty) {
      return _builtInActions();
    }

    return tiles
        .where((tile) => tile.key != 'dasbor' || controller.isManager)
        .map(
          (tile) => _Action(
            tile.label,
            _iconFor(tile.icon),
            _colorFor(tile.color),
            _tapFor(tile),
          ),
        )
        .toList();
  }

  /// Iconsax icon for the name the server stores, falling back to a neutral
  /// glyph so a tile added after this build still renders.
  static IconData _iconFor(String name) => const {
    'category': Iconsax.category,
    'sun_1': Iconsax.sun_1,
    'calendar_remove': Iconsax.calendar_remove,
    'timer_1': Iconsax.timer_1,
    'house': Iconsax.house,
    'calendar_1': Iconsax.calendar_1,
    'clock': Iconsax.clock,
    'arrow_swap_horizontal': Iconsax.arrow_swap_horizontal,
    'receipt_2': Iconsax.receipt_2,
    'wallet_money': Iconsax.wallet_money,
    'wallet_add': Iconsax.wallet_add,
    'receipt_2_1': Iconsax.receipt_2_1,
    'location': Iconsax.location,
    'document_text': Iconsax.document_text,
    'emoji_happy': Iconsax.emoji_happy,
    'flash_1': Iconsax.flash_1,
  }[name] ?? Iconsax.element_3;

  /// `#RRGGBB` to a Color, falling back to the brand blue on anything odd.
  static Color _colorFor(String hex) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);

    return value == null ? const Color(0xFF2F54C9) : Color(0xFF000000 | value);
  }

  /// What the tile does. Everything is a route except Perasaan, which opens a
  /// sheet rather than a page — its route exists only as an identifier.
  VoidCallback _tapFor(MenuTile tile) {
    if (tile.key == 'perasaan') {
      return controller.openMoodDialog;
    }

    return () => Get.toNamed(tile.route);
  }

  /// The tiles compiled into this build, used until the server sends its own.
  List<_Action> _builtInActions() {
    return [
      // Manager first: for the few who see it, the dashboard is their landing
      // point, and it would be buried mid-list otherwise.
      if (controller.isManager)
        _Action(
          'Dasbor',
          Iconsax.category,
          const Color(0xFF7C3AED),
          () => Get.toNamed(Routes.DASHBOARD),
        ),

      // ── Cuti & izin ──
      _Action(
        'Cuti',
        Iconsax.sun_1,
        const Color(0xFF22C55E),
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
        const Color(0xFFF59E0B),
        () => Get.toNamed(Routes.OVERTIME),
      ),
      _Action(
        'WFH',
        Iconsax.house,
        const Color(0xFF0EA5E9),
        () => Get.toNamed(Routes.WFH),
      ),

      // ── Kehadiran & jadwal ──
      _Action(
        'Jadwal',
        Iconsax.calendar_1,
        const Color(0xFF0D9488),
        () => Get.toNamed(Routes.SCHEDULE),
      ),
      _Action(
        'Riwayat',
        Iconsax.clock,
        const Color(0xFF64748B),
        () => Get.toNamed(Routes.RIWAYAT),
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

      // ── Keuangan ──
      _Action(
        'Slip Gaji',
        Iconsax.receipt_2,
        const Color(0xFF0891B2),
        () => Get.toNamed(Routes.PAYSLIP),
      ),
      _Action(
        'Reimburse',
        Iconsax.wallet_money,
        const Color(0xFFDB2777),
        () => Get.toNamed(Routes.REIMBURSEMENT),
      ),
      _Action(
        'Uang Muka',
        Iconsax.wallet_add,
        const Color(0xFF7C3AED),
        () => Get.toNamed(Routes.KASBON),
      ),
      // Settlement follows Uang Muka: it is how an advance is closed out.
      _Action(
        'Settlement',
        Iconsax.receipt_2_1,
        const Color(0xFF2563EB),
        () => Get.toNamed(Routes.SETTLEMENT),
      ),

      // ── Lapangan & referensi ──
      _Action(
        'Kunjungan',
        Iconsax.location,
        const Color(0xFFE11D48),
        () => Get.toNamed(Routes.VISITING),
      ),
      _Action(
        'Dokumen',
        Iconsax.document_text,
        const Color(0xFF9333EA),
        () => Get.toNamed(Routes.DOKUMEN),
      ),
      // SOP is intentionally absent: employees ask the AI assistant instead,
      // which reads the same documents through its `daftar_sop` / `baca_sop`
      // tools. Routes.SOP and its module stay wired up so the screen can be
      // put back by re-adding this entry.

      // ── Sosial ──
      _Action(
        'Perasaan',
        Iconsax.emoji_happy,
        const Color(0xFF2547F9),
        controller.openMoodDialog,
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
              a.pinned ? Iconsax.paperclip_2 : Iconsax.volume_high,
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
          // No room for a labelled chip on this compact row, so a bare icon
          // flags that the announcement carries a file.
          if (a.attachment != null) ...[
            Icon(
              a.attachment!.isImage ? Iconsax.gallery : Iconsax.document_text,
              size: 13.sp,
              color: AppColors.textMuted,
            ),
            SizedBox(width: 6.w),
          ],
          if (a.publishedAt != null)
            Text(
              formatTanggal(a.publishedAt),
              style: TextStyle(color: AppColors.textMuted, fontSize: 10.5.sp),
            ),
        ],
      ),
    );
  }
}

/// Live ticking clock (hh:mm:ss AM/PM) for the attendance hero card.
///
/// It reads the company's clock, not the phone's: an employee travelling with
/// a phone still set to WIB should see the hour their WITA office is keeping,
/// with the zone named so there is no doubt which.
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

  String _text(AttendanceToday? today) {
    final now = today?.nowOnTenantClock() ?? _now;
    final h24 = now.hour;
    final h = (h24 % 12 == 0 ? 12 : h24 % 12).toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ap = h24 < 12 ? 'AM' : 'PM';
    final zone = today?.timezoneLabel ?? '';

    return zone.isEmpty ? '$h:$m:$s $ap' : '$h:$m:$s $ap $zone';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final today = Get.isRegistered<AttendanceController>()
          ? Get.find<AttendanceController>().today.value
          : null;

      return Text(
        _text(today),
        style: TextStyle(
          fontSize: 22.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.navy,
          letterSpacing: -0.5,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    });
  }
}

/// Live worked-hours ticker: counts up from today's clock-in each second until
/// clock-out, then shows the final total (work_minutes) from the server.
// ignore: unused_element
class _LiveWorkedHours extends StatefulWidget {
  const _LiveWorkedHours();

  @override
  State<_LiveWorkedHours> createState() => _LiveWorkedHoursState();
}

class _LiveWorkedHoursState extends State<_LiveWorkedHours> {
  final HomeController _c = Get.find();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(
    String? clockInAt,
    String? clockIn,
    String? clockOut,
    int workMinutes,
  ) {
    bool empty(String? s) => s == null || s.isEmpty || s == '--:--';

    // Clocked out → final total from the server.
    if (!empty(clockOut)) {
      final h = (workMinutes ~/ 60).toString().padLeft(2, '0');
      final m = (workMinutes % 60).toString().padLeft(2, '0');
      return '$h:$m:00';
    }

    // Prefer the full ISO timestamp (second precision); fall back to HH:mm.
    DateTime? start;
    if (clockInAt != null && clockInAt.isNotEmpty) {
      start = DateTime.tryParse(clockInAt)?.toLocal();
    }
    if (start == null && !empty(clockIn)) {
      final p = clockIn!.split(':');
      if (p.length >= 2) {
        final now = DateTime.now();
        start = DateTime(
          now.year,
          now.month,
          now.day,
          int.tryParse(p[0]) ?? 0,
          int.tryParse(p[1]) ?? 0,
        );
      }
    }
    if (start == null) return '00:00:00';

    var d = DateTime.now().difference(start);
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final t = _c.today.value;
      return Text(
        _format(t?.clockInAt, t?.clockIn, t?.clockOut, t?.workMinutes ?? 0),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.navy,
          fontSize: 13.sp,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    });
  }
}

/// Monthly attendance donut: on-time / late / absent segments with a center
/// KPI (attendance %). Drawn with a painter — no chart dependency.
class _AttendanceDonut extends StatelessWidget {
  final List<(double, Color)> segments;
  final String centerText;
  final String centerLabel;

  const _AttendanceDonut({
    required this.segments,
    required this.centerText,
    required this.centerLabel,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DonutPainter(segments),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              centerText,
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              centerLabel,
              style: TextStyle(color: AppColors.textMuted, fontSize: 10.5.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(double, Color)> segments;
  _DonutPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 13.w;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.muted
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    final total = segments.fold<double>(0, (a, s) => a + s.$1);
    if (total <= 0) return;

    const gap = 0.05; // radians between segments
    var start = -math.pi / 2 + gap / 2;
    for (final s in segments) {
      final value = s.$1;
      if (value <= 0) continue;
      final full = (value / total) * (2 * math.pi);
      final sweep = full - gap;
      if (sweep > 0) {
        canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..color = s.$2
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round,
        );
      }
      start += full;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.segments != segments;
}

/// Today's birthdays, as a warm banner rather than another white card: the
/// page is a column of work numbers, and this is the one social item on it —
/// giving it its own colour is what stops it reading as one more stat block.
///
/// Up to three faces are stacked like a photo pile; the rest are counted in the
/// caption, so a company with twenty birthdays still renders one tidy row.
class _BirthdayBanner extends StatelessWidget {
  /// The preview slice from the dashboard — capped by the API, so it can be
  /// shorter than [total].
  final List<BirthdayPerson> people;

  /// Everyone celebrating today, which is what the headline counts.
  final int total;

  /// Opens the full list; null when the banner already shows everyone.
  final VoidCallback? onTap;

  const _BirthdayBanner(this.people, {required this.total, this.onTap});

  /// Warm cream ground and its ink, kept local: these are the only two places
  /// in the app that need a celebratory palette instead of the brand blue.
  static const _cream = Color(0xFFFFF6E9);
  static const _ink = Color(0xFF7C4A03);

  static const maxFaces = 3;

  @override
  Widget build(BuildContext context) {
    final faces = people.take(maxFaces).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20.r),
      child: Material(
        color: _cream,
        child: InkWell(
          onTap: onTap,
          child: CustomPaint(
            painter: const _ConfettiPainter(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 15.h, 16.w, 15.h),
              child: Row(
                children: [
                SizedBox(
                  // Each extra face peeks out by 22 of its 44 logical pixels.
                  width: (44 + (faces.length - 1) * 22).w,
                  height: 44.w,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var i = faces.length - 1; i >= 0; i--)
                        Positioned(
                          left: (i * 22).w,
                          child: _BirthdayAvatar(
                            faces[i],
                            // Only the front face carries the cake, otherwise
                            // the badges collide with the face behind them.
                            showCake: i == 0,
                          ),
                        ),
                    ],
                  ),
                ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _headline(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                            color: _ink,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          _caption(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            height: 1.35,
                            color: _ink.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null) ...[
                    SizedBox(width: 6.w),
                    Icon(
                      Iconsax.arrow_right_3,
                      size: 16.sp,
                      color: _ink.withValues(alpha: 0.55),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _headline() {
    if (total > 1) {
      return '$total rekan berulang tahun hari ini';
    }
    final person = people.first;
    return person.isMe
        ? 'Selamat ulang tahun!'
        : 'Selamat ulang tahun, ${_firstName(person.name)}!';
  }

  String _caption() {
    if (total > 1) {
      // Counted against `total`, not the preview slice: with 23 celebrants the
      // API only sends 12, and "+9 lainnya" would be a lie.
      final shown = people.take(maxFaces).map((p) => _firstName(p.name));
      final rest = total - shown.length;
      return rest > 0
          ? '${shown.join(', ')}, +$rest lainnya'
          : shown.join(', ');
    }
    final person = people.first;
    return person.isMe
        ? 'Semoga tahun ini menyenangkan.'
        : person.role.isEmpty
        ? person.name
        : '${person.name} · ${person.role}';
  }

  static String _firstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? fullName : parts.first;
  }
}

/// The full birthday list, fetched on open. The dashboard only carries a
/// preview slice, so this is the only place a big tenant's whole list appears.
class _BirthdaySheet extends StatefulWidget {
  const _BirthdaySheet();

  @override
  State<_BirthdaySheet> createState() => _BirthdaySheetState();
}

class _BirthdaySheetState extends State<_BirthdaySheet> {
  late Future<List<BirthdayPerson>> _future;

  @override
  void initState() {
    super.initState();
    _future = Get.find<AvanaApi>().birthdays();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Ulang Tahun Hari Ini',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          SizedBox(height: 14.h),
          FutureBuilder<List<BirthdayPerson>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.h),
                  child: Center(
                    child: SizedBox(
                      width: 24.w,
                      height: 24.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                );
              }

              final people = snapshot.data ?? const <BirthdayPerson>[];
              if (snapshot.hasError || people.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 28.h),
                  child: Text(
                    snapshot.hasError
                        ? 'Gagal memuat daftar. Coba lagi nanti.'
                        : 'Tidak ada yang berulang tahun hari ini.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
                );
              }

              return Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: people.length,
                  separatorBuilder: (_, _) => SizedBox(height: 10.h),
                  itemBuilder: (context, index) {
                    final person = people[index];
                    return Row(
                      children: [
                        _BirthdayAvatar(person),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                person.isMe ? '${person.name} (Anda)' : person.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                              if (person.role.isNotEmpty) ...[
                                SizedBox(height: 1.h),
                                Text(
                                  person.role,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5.sp,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A celebrant's photo (or initials) in a white ring, optionally cake-badged.
class _BirthdayAvatar extends StatelessWidget {
  final BirthdayPerson person;
  final bool showCake;

  const _BirthdayAvatar(this.person, {this.showCake = false});

  @override
  Widget build(BuildContext context) {
    final size = 44.w;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: person.avatarColor,
              // The ring is what separates overlapping faces from each other.
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipOval(
              child: person.photoUrl == null
                  ? _initials()
                  : Image.network(
                      person.photoUrl!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _initials(),
                    ),
            ),
          ),
          if (showCake)
            Positioned(
              right: -2.w,
              bottom: -1.h,
              child: Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.warning,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Icon(Iconsax.cake, size: 9.sp, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initials() {
    return Text(
      person.initials,
      style: TextStyle(
        color: Colors.white,
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Scattered confetti behind the birthday banner — a handful of tilted slivers
/// and dots. Positions come from a fixed table, not a random source, so the
/// pattern is identical on every rebuild instead of twitching as the page
/// repaints.
class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter();

  /// `(x, y)` as a fraction of the banner, tilt in turns, and colour index.
  static const List<(double, double, double, int)> _pieces = [
    (0.30, 0.18, 0.10, 0),
    (0.44, 0.72, 0.35, 1),
    (0.57, 0.12, 0.62, 2),
    (0.68, 0.55, 0.18, 0),
    (0.79, 0.24, 0.44, 1),
    (0.88, 0.78, 0.08, 2),
    (0.95, 0.40, 0.55, 0),
  ];

  static const List<Color> _colors = [
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF22C55E),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (fx, fy, turn, colorIndex) in _pieces) {
      final paint = Paint()..color = _colors[colorIndex].withValues(alpha: 0.22);
      canvas.save();
      canvas.translate(fx * size.width, fy * size.height);
      canvas.rotate(turn * 2 * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, -1.25, 6, 2.5),
          const Radius.circular(1.25),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => false;
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
  const _MenuCarousel(this.actions, {super.key});

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
