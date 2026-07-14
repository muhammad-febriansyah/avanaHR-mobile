import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../data/services/attendance_queue_service.dart';
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
          _pendingBanner(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  /// A slim amber bar shown while queued clock actions await sync.
  Widget _pendingBanner() {
    final queue = Get.find<AttendanceQueueService>();
    return Obx(() {
      if (queue.pendingCount.value == 0) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        color: const Color(0xFFFEF3C7),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Row(
          children: [
            Icon(Iconsax.clock, size: 15.sp, color: const Color(0xFFB45309)),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                '${queue.pendingCount.value} absen menunggu sinkron — terkirim otomatis saat online',
                style: TextStyle(
                  fontSize: 11.5.sp,
                  color: const Color(0xFFB45309),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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
          await controller.detectLocation();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          // Extra bottom inset so the map/content clears the docked center FAB.
          padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 72.h),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _geoStatus(),
                  SizedBox(height: 14.h),
                  _todayCard(),
                  SizedBox(height: 18.h),
                  _clockButton(),
                  SizedBox(height: 8.h),
                  Text(
                    'Wajah, lokasi & perangkat direkam saat absen.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5.sp,
                    ),
                    textAlign: TextAlign.center,
                  ),
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

  /// Primary clock action. Runs the geofence + face gate: taps launch the
  /// full-screen face page ([Routes.FACE_VERIFY] / [Routes.FACE_ENROLL]) via
  /// [AttendanceController.clock], then submit.
  Widget _clockButton() {
    return Obx(() {
      final isIn = controller.today.value?.canClockIn ?? true;
      final busy = controller.isClocking.value;
      final blocked = !controller.canClockByLocation;
      return SizedBox(
        width: double.infinity,
        height: 54.h,
        child: ElevatedButton.icon(
          onPressed: busy || blocked ? null : controller.clock,
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
              : Icon(isIn ? Iconsax.login_1 : Iconsax.logout_1, size: 20.sp),
          label: Text(
            busy
                ? 'Memproses…'
                : blocked
                ? 'Di luar radius kantor'
                : isIn
                ? 'Absen Masuk (Scan Wajah)'
                : 'Absen Pulang (Scan Wajah)',
            style: TextStyle(fontSize: 14.5.sp, fontWeight: FontWeight.w700),
          ),
        ),
      );
    });
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
          color = AppColors.textMuted;
          icon = Iconsax.location;
          title = 'Mendeteksi lokasi…';
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
          sub = '$dist m — mendekat untuk absen';
          break;
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
          sub = 'Beri izin lokasi untuk memvalidasi radius';
          break;
        case GeoState.noOffice:
          color = AppColors.textMuted;
          icon = Iconsax.building;
          title = 'Belum ada titik kantor';
          sub = 'Absen tetap bisa dilakukan';
          break;
        case GeoState.error:
          color = AppColors.textMuted;
          icon = Iconsax.info_circle;
          title = 'Lokasi tak terbaca';
          sub = 'Absen tetap bisa dilakukan';
          break;
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
                    onTap: controller.detectLocation,
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

  Widget _statusChip(String status) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: AppColors.primary,
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
