import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_storage/get_storage.dart';

import '../../core/utils/selfie_stamp.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/models/attendance.dart';
import '../../data/models/dashboard.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';
import '../../data/services/attendance_queue_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/connectivity_service.dart';
import '../../data/services/device_service.dart';
import '../../routes/app_pages.dart';
import 'widgets/clock_dialogs.dart';

/// Geofence state for the attendance screen's map + clock gate.
enum GeoState { loading, inside, outside, gpsOff, denied, noOffice, error }

class AttendanceController extends GetxController with WidgetsBindingObserver {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final isClocking = false.obs;
  final today = Rxn<AttendanceToday>();

  /// Where the employee says they are working from: 'office' or 'home'.
  /// 'home' is only offered — and only accepted by the server — on a day an
  /// approved WFH request covers.
  final workMode = 'office'.obs;

  /// Whether picking "home" is legal today.
  bool get canWorkFromHome => today.value?.wfhApprovedToday ?? false;

  /// Clocking out must stay in the mode the day was clocked in under.
  String get effectiveWorkMode => today.value?.workMode ?? workMode.value;

  /// Whether the employee has enrolled a face and must verify before clocking.
  /// Cached so an offline launch still knows to prompt for the capture.
  final requiresFace = false.obs;
  final GetStorage _box = GetStorage();
  static const _faceKey = 'face_required';

  // Geofence / map state.
  final geoState = GeoState.loading.obs;
  final nearest = Rxn<WorkLocationItem>();
  final distanceMeters = 0.0.obs;
  final userLat = Rxn<double>();
  final userLng = Rxn<double>();
  final isLocating = false.obs;

  /// Clock is allowed inside the radius, or when we cannot verify location
  /// (no office configured / GPS unavailable) — so users are never trapped.
  ///
  /// Working from home is off-site by definition, so the radius must not gate
  /// it; the server checks the WFH approval instead.
  bool get canClockByLocation =>
      effectiveWorkMode == 'home' ||
      geoState.value == GeoState.inside ||
      geoState.value == GeoState.noOffice ||
      geoState.value == GeoState.gpsOff ||
      geoState.value == GeoState.denied ||
      geoState.value == GeoState.error;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    requiresFace.value = _box.read<bool>(_faceKey) ?? false;
    load();
    detectLocation();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  /// This controller lives for the whole session (bottom-nav tab), so a
  /// forgotten clock-out yesterday would otherwise leave `today` stuck on
  /// yesterday's open record. When the app returns to the foreground on a new
  /// calendar day, re-pull today's attendance so the button resets to a fresh
  /// clock-in instead of continuing the old session.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && (_isStaleDay || today.value == null)) {
      load();
    }
  }

  /// Local calendar date as `YYYY-MM-DD`.
  String _localToday() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');

    return '${n.year}-$m-$d';
  }

  /// True when the loaded `today` belongs to an earlier calendar day.
  bool get _isStaleDay {
    final date = today.value?.date;

    return date != null && date != _localToday();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      today.value = await _api.attendanceToday();
    } catch (_) {
      today.value = null;
    }
    isLoading.value = false;

    // An approval can be revoked, or the day can roll over, while the selector
    // still says "home" — never leave a choice the server would now reject.
    if (!canWorkFromHome) {
      workMode.value = 'office';
    }

    _refreshFaceRequirement();
  }

  /// Best-effort refresh of the face-enrollment flag from the API.
  Future<void> _refreshFaceRequirement() async {
    try {
      final res = await _api.faceStatus();
      final enrolled = (res.data['data']?['enrolled'] as bool?) ?? false;
      requiresFace.value = enrolled;
      _box.write(_faceKey, enrolled);
    } catch (_) {
      // Offline / error: keep the cached value.
    }
  }

  /// Resolve the nearest office geofence + the user's live position for the
  /// map and the clock gate. Best-effort; never throws.
  Future<void> detectLocation() async {
    if (isLocating.value) return;
    isLocating.value = true;
    geoState.value = GeoState.loading;
    try {
      final locations = await _api.workLocations();
      final withCoords = locations
          .where((l) => l.latitude != null && l.longitude != null)
          .toList();

      if (!await Geolocator.isLocationServiceEnabled()) {
        geoState.value = GeoState.gpsOff;

        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        geoState.value = GeoState.denied;

        return;
      }

      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        if (last == null) {
          geoState.value = GeoState.error;

          return;
        }
        pos = last;
      }

      userLat.value = pos.latitude;
      userLng.value = pos.longitude;

      if (withCoords.isEmpty) {
        geoState.value = GeoState.noOffice;

        return;
      }

      WorkLocationItem? closest;
      var closestDistance = double.infinity;
      for (final loc in withCoords) {
        final d = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          loc.latitude!,
          loc.longitude!,
        );
        if (d < closestDistance) {
          closestDistance = d;
          closest = loc;
        }
      }

      nearest.value = closest;
      distanceMeters.value = closestDistance;
      final within =
          (closest!.radius <= 0) || closestDistance <= closest.radius;
      geoState.value = within ? GeoState.inside : GeoState.outside;
    } catch (_) {
      geoState.value = GeoState.error;
    } finally {
      isLocating.value = false;
    }
  }

  /// Marks the caller as face-enrolled locally (used by the on-page scanner
  /// after it enrolls a template server-side).
  void markFaceEnrolled() {
    requiresFace.value = true;
    _box.write(_faceKey, true);
  }

  /// Whether the geofence currently allows clocking; the on-page scanner uses
  /// this to decide whether to run the camera.
  bool get canClockNow => canClockByLocation && !isClocking.value;

  /// Full clock action with the built-in navigating face gate. Kept for entry
  /// points that push the standalone camera route.
  Future<void> clock() => _runClock(navigateFaceGate: true);

  /// Clock using a face embedding already captured by the on-page scanner —
  /// no navigation. Pass null when enrollment just happened (no verify needed).
  Future<void> clockWithEmbedding(List<double>? faceEmbedding) =>
      _runClock(navigateFaceGate: false, providedEmbedding: faceEmbedding);

  Future<void> _runClock({
    required bool navigateFaceGate,
    List<double>? providedEmbedding,
  }) async {
    // A day may have rolled over while the app sat in memory; refresh first so
    // we never clock out on a new day against yesterday's open record.
    if (_isStaleDay) {
      await load();
    }

    final type = today.value?.canClockIn ?? true ? 'in' : 'out';

    // Geofence gate: block only when we positively know the user is outside a
    // real office radius. Unknown location never blocks (see canClockByLocation).
    if (!canClockByLocation) {
      final office = nearest.value?.name ?? 'kantor';
      AppToast.warning(
        'Di luar radius $office (${distanceMeters.value.round()} m). Mendekat ke lokasi untuk absen.',
      );

      return;
    }

    // Face gate — driven by the tenant policy (requirements.face_mode):
    //   'off'         → skip face entirely.
    //   'detection'   → capture a live face; the server accepts it without a match.
    //   'recognition' → capture + the server matches it against the template.
    // Already enrolled → verify against the stored template; not yet enrolled →
    // run enrollment (active liveness) first, then clock. Capture + embedding
    // both run locally, so this works offline too.
    final requiresFaceCapture = today.value?.requiresFaceCapture ?? true;
    List<double>? faceEmbedding = providedEmbedding;
    String? selfiePath;
    if (navigateFaceGate && requiresFaceCapture) {
      if (requiresFace.value) {
        final result = await Get.toNamed(Routes.FACE_VERIFY);
        if (result is! Map || result['embedding'] is! List) {
          AppToast.warning('Verifikasi wajah dibatalkan.');

          return;
        }
        faceEmbedding = List<double>.from(result['embedding'] as List);
        selfiePath = result['photo'] as String?;
      } else {
        // Not enrolled yet → explain first so the flow is clear, then register.
        // The just-captured template + frame are reused for this same punch (the
        // backend blocks a clock with no embedding, so a fall-through would 422).
        final wantEnroll = await confirmFaceEnroll();
        if (!wantEnroll) {
          return;
        }
        final result = await Get.toNamed(Routes.FACE_ENROLL);
        if (result is! Map || result['embedding'] is! List) {
          AppToast.warning('Pendaftaran wajah dibatalkan.');

          return;
        }
        markFaceEnrolled();
        faceEmbedding = List<double>.from(result['embedding'] as List);
        selfiePath = result['photo'] as String?;
      }
    }

    isClocking.value = true;
    showClockLoader();
    try {
      final pos = await _currentPosition();
      final deviceService = Get.find<DeviceService>();
      final device = await deviceService.current();
      final isRooted = await deviceService.isCompromised();
      final isEmulator = await deviceService.isEmulator();

      // Un-mirror the front-camera selfie and stamp company/identity/time/GPS
      // onto it before upload. The face embedding was already computed from the
      // raw shot, so this only affects the stored photo.
      if (selfiePath != null) {
        final me = Get.find<AuthService>().user.value;
        final address = pos != null
            ? await _describeAddress(pos.latitude, pos.longitude)
            : null;
        selfiePath = await SelfieStamp.apply(
          path: selfiePath,
          company: me?.employee?.employment?.company,
          subtitle: me?.employee?.fullName ?? me?.name,
          address: address,
          latitude: pos?.latitude,
          longitude: pos?.longitude,
          at: DateTime.now(),
        );
      }

      final entry = <String, dynamic>{
        'type': type,
        'work_mode': effectiveWorkMode,
        'latitude': pos?.latitude,
        'longitude': pos?.longitude,
        'device_id': device.deviceId,
        'is_mock_location': pos?.isMocked ?? false,
        'is_rooted': isRooted,
        'is_emulator': isEmulator,
        'clocked_at': DateTime.now().toIso8601String(),
        if (faceEmbedding != null) 'face_embedding': faceEmbedding,
      };

      // No internet → queue it and reflect the action locally.
      if (!Get.find<ConnectivityService>().online.value) {
        hideClockLoader();
        _queueOffline(type, entry);
        return;
      }

      try {
        final res = await _api.clock(
          type: type,
          workMode: effectiveWorkMode,
          latitude: pos?.latitude,
          longitude: pos?.longitude,
          faceEmbedding: faceEmbedding,
          deviceId: device.deviceId,
          isMockLocation: pos?.isMocked ?? false,
          isRooted: isRooted,
          isEmulator: isEmulator,
          selfiePath: selfiePath,
        );
        hideClockLoader();
        final code = res.statusCode ?? 0;
        if (code >= 200 && code < 300) {
          await load();
          showClockResult(
            success: true,
            message: ApiClient.messageFrom(res, 'Absensi berhasil dicatat.'),
          );
        } else {
          showClockResult(
            success: false,
            message: ApiClient.messageFrom(res, 'Gagal mencatat absensi.'),
          );
        }
      } on DioException catch (e) {
        hideClockLoader();
        // Lost connection mid-request → fall back to the offline queue.
        if (_isNetworkError(e)) {
          _queueOffline(type, entry);
        } else {
          showClockResult(success: false, message: ApiClient.errorMessage(e));
        }
      }
    } catch (_) {
      // Anything unexpected while preparing the punch — never leave the loader
      // spinning.
      hideClockLoader();
      showClockResult(
        success: false,
        message: 'Terjadi kesalahan. Coba lagi.',
      );
    } finally {
      isClocking.value = false;
    }
  }

  void _queueOffline(String type, Map<String, dynamic> entry) {
    Get.find<AttendanceQueueService>().enqueue(entry);
    _applyOptimistic(type);
    AppToast.info(
      'Tidak ada internet. Absen disimpan & dikirim otomatis saat online.',
    );
  }

  bool _isNetworkError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout;

  /// Reverse-geocode a fix into a short human address for the selfie watermark.
  /// Best-effort — returns null when geocoding gives nothing.
  Future<String?> _describeAddress(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) {
        return null;
      }
      final p = marks.first;
      final parts = <String?>[
        p.street,
        p.subLocality,
        p.locality,
        p.subAdministrativeArea,
      ].where((e) => e != null && e.trim().isNotEmpty).cast<String>().toList();

      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  /// Reflect a queued clock action in today's status immediately.
  void _applyOptimistic(String type) {
    final now = DateTime.now();
    final hm =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final t = today.value;
    final date = t?.date ?? now.toIso8601String().split('T').first;

    if (type == 'in') {
      today.value = AttendanceToday(
        date: date,
        nextAction: 'out',
        clockIn: hm,
        clockOut: t?.clockOut,
        status: 'present',
        workMinutes: t?.workMinutes ?? 0,
      );
    } else {
      today.value = AttendanceToday(
        date: date,
        nextAction: 'done',
        clockIn: t?.clockIn,
        clockOut: hm,
        status: t?.status,
        workMinutes: t?.workMinutes ?? 0,
      );
    }
  }

  /// Best-effort GPS; returns null if permission denied or location off.
  Future<Position?> _currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        return await Geolocator.getLastKnownPosition();
      }
    } catch (_) {
      return null;
    }
  }
}
