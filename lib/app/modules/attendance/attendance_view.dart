import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../data/services/attendance_queue_service.dart';
import '../../data/services/connectivity_service.dart';
import '../../data/services/tracking_service.dart';
import '../../routes/app_pages.dart';
import 'attendance_controller.dart';

class AttendanceView extends GetView<AttendanceController> {
  const AttendanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Absensi',
      subtitle: 'Clock in / clock out',
      // As the center-FAB tab there's nothing to pop, so hide the back arrow;
      // when opened as a standalone pushed route, show it.
      showBack: Navigator.of(context).canPop(),
      child: Column(
        children: [
          _offlineBanner(),
          _pendingBanner(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  /// Standing notice while the internet is unreachable.
  ///
  /// Being offline used to surface only as a toast after a tap that went
  /// nowhere — the state was invisible until the employee tried and failed.
  /// What it says depends on whether a punch can still be made: with the face
  /// check off the punch is queued, with recognition on it cannot happen at
  /// all, and promising a queue in that case would be a lie.
  Widget _offlineBanner() {
    final connectivity = Get.find<ConnectivityService>();

    return Obx(() {
      final status = connectivity.status.value;
      if (status == ConnStatus.online) return const SizedBox.shrink();

      final blocked = controller.requiresOnlineFace;
      final color = blocked ? AppColors.destructive : const Color(0xFFB45309);
      final background = blocked
          ? const Color(0xFFFEE2E2)
          : const Color(0xFFFEF3C7);
      final headline = status == ConnStatus.unstable
          ? 'Internet tidak stabil'
          : 'Tidak ada internet';
      final detail = blocked
          ? 'Absen belum bisa dilakukan — daftarkan wajah dulu saat online.'
          : 'Absen tetap bisa dilakukan dan terkirim otomatis saat online.';

      return Material(
        color: background,
        child: InkWell(
          onTap: connectivity.recheck,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
            child: Row(
              children: [
                Icon(Iconsax.wifi_square, size: 15.sp, color: color),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    '$headline. $detail',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Iconsax.refresh, size: 15.sp, color: color),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// Shows queued actions and server rejections that need a correction request.
  Widget _pendingBanner() {
    final queue = Get.find<AttendanceQueueService>();
    return Obx(() {
      final failed = queue.failedCount.value;
      final pending = queue.pendingCount.value;
      if (failed == 0 && pending == 0) return const SizedBox.shrink();
      final color = failed > 0
          ? AppColors.destructive
          : const Color(0xFFB45309);
      final background = failed > 0
          ? const Color(0xFFFEE2E2)
          : const Color(0xFFFEF3C7);
      final message = failed > 0
          ? queue.lastFailure.value ??
                '$failed absensi ditolak. Ajukan koreksi absensi.'
          : '$pending absen menunggu sinkron dan akan terkirim saat online';

      return Material(
        color: background,
        child: InkWell(
          onTap: failed > 0
              ? () => Get.toNamed(Routes.ATTENDANCE_CORRECTION)
              : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
            child: Row(
              children: [
                Icon(
                  failed > 0 ? Iconsax.warning_2 : Iconsax.clock,
                  size: 15.sp,
                  color: color,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (failed > 0)
                  Icon(Iconsax.arrow_right_3, size: 15.sp, color: color),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _body() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      return RefreshIndicator(
        onRefresh: () async {
          await controller.load();
          // A pull is the employee retrying: the chip is in front of them, so
          // a failure answers there rather than with a dialog on top.
          await controller.detectLocation(userAsked: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          // Top gap so the status alert isn't flush against the app bar; bottom
          // inset so the map/content clears the floating nav bar.
          padding: EdgeInsets.fromLTRB(
            20.w,
            16.h,
            20.w,
            AppPage.bottomNavClearance(Get.context!),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _geoStatus(),
                  SizedBox(height: 14.h),
                  _todayCard(),
                  _trackingStatus(),
                  _workModePicker(),
                  SizedBox(height: 18.h),
                  _clockButton(),
                  SizedBox(height: 8.h),
                  Obx(() {
                    // Say what this particular punch will do. Offline with the
                    // face check off, it is stored and sent later — worth
                    // saying, so the employee does not read the missing
                    // confirmation as a punch that never happened.
                    final queues = controller.queuesOffline;
                    // Under a blocking face policy the match happens at sync,
                    // so the punch is provisional until then. Saying "tersimpan"
                    // and nothing else would let an employee walk away believing
                    // a punch is settled that the server may still refuse.
                    final verifiedLater =
                        queues &&
                        (controller.today.value?.blocksOnFaceFailure ?? true);

                    return Text(
                      verifiedLater
                          ? 'Tanpa internet — absen disimpan dan dikirim saat online. Wajah dicocokkan saat itu.'
                          : queues
                          ? 'Tanpa internet — absen disimpan di perangkat dan terkirim otomatis saat online.'
                          : 'Wajah, lokasi & perangkat direkam saat absen.',
                      style: TextStyle(
                        color: queues
                            ? const Color(0xFFB45309)
                            : AppColors.textMuted,
                        fontSize: 11.5.sp,
                        fontWeight: queues ? FontWeight.w600 : FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    );
                  }),
                  SizedBox(height: 18.h),
                  // Map sits at the bottom as location confirmation.
                  const _GeofenceMap(),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  /// Office/home choice, offered only on a day an approved WFH request covers —
  /// the server rejects "home" otherwise, so there is nothing to show. Hidden
  /// once clocked in: the mode is fixed for the rest of the day.
  Widget _workModePicker() {
    return Obx(() {
      final clockedIn = !(controller.today.value?.canClockIn ?? true);

      if (!controller.canWorkFromHome || clockedIn) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: EdgeInsets.only(top: 14.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mode kerja hari ini',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
                fontSize: 12.5.sp,
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: _workModeOption(
                    'office',
                    Iconsax.building_4,
                    'Kantor',
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _workModeOption('home', Iconsax.home_2, 'Rumah'),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _workModeOption(String value, IconData icon, String label) {
    final selected = controller.workMode.value == value;

    return GestureDetector(
      onTap: () => controller.workMode.value = value,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.muted,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16.sp,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textMuted,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 12.5.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Primary clock action. Runs the geofence + face gate: taps launch the
  /// full-screen face page ([Routes.FACE_VERIFY] / [Routes.FACE_ENROLL]) via
  /// [AttendanceController.clock], then submit.
  Widget _clockButton() {
    return Obx(() {
      final isIn = controller.today.value?.canClockIn ?? true;
      final done = controller.isDoneToday;
      final busy = controller.isClocking.value;
      final unavailable =
          controller.today.value == null || controller.loadFailed.value;
      final blocked = !unavailable && !done && !controller.canClockByLocation;
      // A punch the face policy cannot complete offline is shut here rather
      // than after the tap: the old screen left this button fully lit, and the
      // only way to learn it would fail was to press it and read a toast.
      final offline =
          !unavailable && !done && controller.offlineBlockReason != null;
      // Still resolving is not the same as being outside the fence — saying so
      // reads as a refusal on a screen that is merely waiting.
      final locating = controller.geoState.value == GeoState.loading;
      return SizedBox(
        width: double.infinity,
        height: 54.h,
        child: ElevatedButton.icon(
          onPressed: busy || unavailable || blocked || offline || done
              ? null
              : controller.clock,
          style: ElevatedButton.styleFrom(
            backgroundColor: isIn ? AppColors.primary : AppColors.destructive,
            disabledBackgroundColor: AppColors.textMuted.withValues(alpha: 0.3),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
          ),
          icon: busy
              ? SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Icon(
                  done
                      ? Iconsax.tick_circle
                      : offline
                      ? Iconsax.wifi_square
                      : isIn
                      ? Iconsax.login_1
                      : Iconsax.logout_1,
                  size: 20.sp,
                ),
          label: Text(
            busy
                ? 'Memproses…'
                : unavailable
                ? 'Status absensi gagal dimuat - tarik untuk mencoba lagi'
                : done
                ? 'Absensi hari ini selesai'
                : locating
                ? 'Mendeteksi lokasi…'
                : blocked
                ? _blockedLabel(controller.geoState.value)
                : offline
                ? 'Tanpa internet — scan wajah tak bisa'
                : isIn
                ? 'Absen Masuk (Scan Wajah)'
                : 'Absen Pulang (Scan Wajah)',
            style: TextStyle(fontSize: 14.5.sp, fontWeight: FontWeight.w700),
          ),
        ),
      );
    });
  }

  /// Short reason on the disabled button. "Di luar radius" is only one of the
  /// ways the clock can be shut, and the wrong one to show a user whose GPS is
  /// simply off — the chip above carries the full sentence.
  String _blockedLabel(GeoState state) {
    switch (state) {
      case GeoState.outside:
        return 'Di luar radius kantor';
      case GeoState.gpsOff:
        return 'GPS mati — aktifkan lokasi';
      case GeoState.denied:
        return 'Izin lokasi ditolak';
      case GeoState.noOffice:
        return 'Titik kantor belum diatur';
      case GeoState.serverValidation:
        return 'Radius diperiksa saat absen';
      default:
        return 'Lokasi belum terbaca';
    }
  }

  // ---- Geofence status chip -------------------------------------------------

  Widget _geoStatus() {
    return Obx(() {
      final st = controller.geoState.value;
      final dist = controller.distanceMeters.value.round();
      final office = controller.nearest.value?.name;

      late final Color color;
      late final IconData icon;
      late final String title;
      String? sub;

      switch (st) {
        case GeoState.loading:
          final seconds = controller.locatingSeconds.value;
          color = AppColors.textMuted;
          icon = Iconsax.location;
          title = 'Mendeteksi lokasi…';
          // Counted only once the wait is long enough to worry about, so a
          // normal two-second fix stays quiet.
          sub = seconds >= 5
              ? 'Mencari sinyal GPS ($seconds dtk) — di dalam ruangan bisa lebih lama'
              : null;
          break;
        case GeoState.inside:
          color = AppColors.success;
          icon = Iconsax.tick_circle;
          title = 'Dalam radius${office != null ? ' · $office' : ''}';
          sub = '$dist m dari titik kantor';
          break;
        case GeoState.outside:
          color = AppColors.destructive;
          icon = Iconsax.close_circle;
          title = 'Di luar radius${office != null ? ' · $office' : ''}';
          // A fix too coarse to judge against the radius is the likelier
          // explanation than an employee kilometres from an office they are
          // sitting in — and the clock button is disabled in this state, so
          // this chip is the only place the remedy can still be read.
          sub = controller.isCoarseFix
              ? '$dist m. ${controller.coarseFixAdvice}'
              : '$dist m — mendekat untuk absen';
          break;
        case GeoState.anywhere:
          // WFA drops the radius, not the fix: the server still records — and
          // still requires — a coordinate on every punch.
          final located = controller.userLat.value != null;
          color = located ? AppColors.success : AppColors.warning;
          icon = Iconsax.global;
          title = 'WFA — absen di mana saja';
          sub = !located
              ? 'Radius tidak dicek, tapi GPS wajib aktif untuk absen'
              : office != null
              ? 'Radius tidak dicek · terdekat $office ($dist m)'
              : 'Radius tidak dicek, lokasi tetap direkam';
          break;
        case GeoState.serverValidation:
          color = AppColors.warning;
          icon = Iconsax.location_tick;
          title = 'Lokasi ditemukan';
          sub = 'Koneksi kebijakan lokasi lambat · radius diperiksa saat absen';
          break;
        // The three states below all end in a punch the server refuses — it
        // wants coordinates on every clock, WFA included — so the chip says so
        // instead of promising an absen that would 422.
        case GeoState.gpsOff:
          color = AppColors.warning;
          icon = Iconsax.gps_slash;
          title = 'GPS mati';
          sub = 'Aktifkan lokasi lalu tarik untuk memuat ulang';
          break;
        case GeoState.denied:
          color = AppColors.warning;
          icon = Iconsax.location_slash;
          title = 'Izin lokasi ditolak';
          sub = 'Beri izin lokasi untuk bisa absen';
          break;
        case GeoState.noOffice:
          color = AppColors.warning;
          icon = Iconsax.building;
          title = 'Belum ada titik kantor';
          sub = 'Lokasi kerja belum diatur admin — hubungi HR';
          break;
        case GeoState.error:
          color = AppColors.warning;
          icon = Iconsax.info_circle;
          title = 'Lokasi tak terbaca';
          sub = 'Periksa GPS lalu tarik untuk memuat ulang';
          break;
      }

      // Offline the punch no longer waits on a fix: it is queued and the
      // location is filled in when the connection returns. Saying "periksa GPS"
      // here would send an employee chasing a signal they do not need.
      if (controller.queuesOffline &&
          controller.userLat.value == null &&
          st != GeoState.loading) {
        sub =
            'Tanpa internet — absen tetap bisa, lokasi diisi otomatis saat '
            'koneksi pulih';
      }

      return Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (sub != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      sub,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5.sp,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            controller.isLocating.value
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : InkWell(
                    onTap: () => controller.detectLocation(userAsked: true),
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: EdgeInsets.all(8.w),
                      child: Icon(Iconsax.refresh, color: color, size: 18.sp),
                    ),
                  ),
          ],
        ),
      );
    });
  }

  // ---- Today card -----------------------------------------------------------

  Widget _todayCard() {
    final t = controller.today.value;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Absensi Hari Ini',
                style: TextStyle(
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const Spacer(),
              if (t?.status != null) _statusChip(t!.status!),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _timeCol(
                  Iconsax.login_1,
                  'Masuk',
                  t?.clockIn ?? '--:--',
                  AppColors.success,
                ),
              ),
              Container(width: 1, height: 46.h, color: AppColors.border),
              Expanded(
                child: _timeCol(
                  Iconsax.logout_1,
                  'Pulang',
                  t?.clockOut ?? '--:--',
                  AppColors.destructive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Explicit privacy indicator: tracking is never hidden behind Clock In.
  Widget _trackingStatus() {
    final tracking = Get.find<TrackingService>();

    return Obx(() {
      final today = controller.today.value;
      final duringWork = today != null && !today.canClockIn && !today.isDone;
      final active = tracking.isTracking.value;
      final message = tracking.warning.value;

      if (!duringWork && !active) return const SizedBox.shrink();

      final color = active ? AppColors.success : AppColors.warning;
      final pending = tracking.pendingPoints.value;

      return Container(
        width: double.infinity,
        margin: EdgeInsets.only(top: 12.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34.w,
              height: 34.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                active ? Iconsax.location_tick : Iconsax.warning_2,
                color: color,
                size: 18.sp,
              ),
            ),
            SizedBox(width: 11.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active ? 'Tracking Aktif' : 'Tracking Belum Aktif',
                    style: TextStyle(
                      color: color,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    active
                        ? 'Lokasi dicatat selama jam kerja dan berhenti saat Clock Out.'
                        : message ??
                              'Izin background location diperlukan untuk tracking.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5.sp,
                      height: 1.35,
                    ),
                  ),
                  if (pending > 0) ...[
                    SizedBox(height: 4.h),
                    Text(
                      '$pending titik tersimpan dan akan disinkronkan otomatis.',
                      style: TextStyle(
                        color: color,
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _statusChip(String status) {
    final normalized = status.trim().toLowerCase();
    final (label, color) = switch (normalized) {
      'present' => ('Hadir', AppColors.success),
      'late' => ('Terlambat', AppColors.warning),
      'absent' => ('Tidak Hadir', AppColors.destructive),
      'incomplete' => ('Belum Lengkap', AppColors.warning),
      'leave' => ('Cuti', AppColors.primary),
      _ => (status, AppColors.textMuted),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _timeCol(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 26.w,
              height: 26.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(icon, color: color, size: 14.sp),
            ),
            SizedBox(width: 7.w),
            Text(
              label,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Interactive OpenStreetMap card showing the office geofence circle, the
/// office marker, and the employee's live position, with a recenter control.
class _GeofenceMap extends StatefulWidget {
  const _GeofenceMap();

  @override
  State<_GeofenceMap> createState() => _GeofenceMapState();
}

class _GeofenceMapState extends State<_GeofenceMap> {
  final MapController _map = MapController();

  static const _fallback = LatLng(-6.2088, 106.8456); // Jakarta

  Worker? _centerWorker;
  bool _autoCentered = false;

  @override
  void initState() {
    super.initState();
    final c = Get.find<AttendanceController>();
    // Auto-center on the user's live GPS location the moment it's detected.
    _centerWorker = ever(c.userLat, (_) => _autoCenterUser(c));
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoCenterUser(c));
  }

  void _autoCenterUser(AttendanceController c) {
    if (_autoCentered) return;
    final u = _userOf(c);
    if (u == null) return;
    _autoCentered = true;
    _map.move(u, 16);
  }

  @override
  void dispose() {
    _centerWorker?.dispose();
    super.dispose();
  }

  LatLng? _officeOf(AttendanceController c) {
    final o = c.nearest.value;
    if (o?.latitude == null || o?.longitude == null) return null;
    return LatLng(o!.latitude!, o.longitude!);
  }

  LatLng? _userOf(AttendanceController c) {
    if (c.userLat.value == null || c.userLng.value == null) return null;
    return LatLng(c.userLat.value!, c.userLng.value!);
  }

  void _recenter() {
    final c = Get.find<AttendanceController>();
    _map.move(_userOf(c) ?? _officeOf(c) ?? _fallback, 16);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AttendanceController>();

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18.r)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.r),
        child: SizedBox(
          height: 230.h,
          child: Obx(() {
            final office = _officeOf(controller);
            final user = _userOf(controller);
            final center = user ?? office ?? _fallback;
            final radius = (controller.nearest.value?.radius ?? 0).toDouble();

            return Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 16,
                    minZoom: 3,
                    maxZoom: 19,
                    interactionOptions: const InteractionOptions(
                      flags:
                          InteractiveFlag.pinchZoom |
                          InteractiveFlag.drag |
                          InteractiveFlag.doubleTapZoom,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'id.avanahr.mobile',
                      tileProvider: NetworkTileProvider(),
                    ),
                    if (office != null && radius > 0)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: office,
                            radius: radius,
                            useRadiusInMeter: true,
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderColor: AppColors.primary.withValues(
                              alpha: 0.6,
                            ),
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // Single default pin at the user's position (fallback to
                        // the office point when GPS isn't available yet).
                        if (user != null || office != null)
                          Marker(
                            point: (user ?? office)!,
                            width: 40.w,
                            height: 40.w,
                            alignment: Alignment.bottomCenter,
                            child: Icon(
                              Icons.location_pin,
                              color: AppColors.primary,
                              size: 40.sp,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 10.w,
                  bottom: 10.h,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 0,
                    child: InkWell(
                      onTap: _recenter,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 44.w,
                        height: 44.w,
                        child: Icon(
                          Iconsax.gps,
                          color: AppColors.primary,
                          size: 22.sp,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 6.w,
                  bottom: 4.h,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 5.w,
                      vertical: 1.h,
                    ),
                    color: Colors.white.withValues(alpha: 0.7),
                    child: Text(
                      '© OpenStreetMap',
                      style: TextStyle(
                        fontSize: 8.5.sp,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
