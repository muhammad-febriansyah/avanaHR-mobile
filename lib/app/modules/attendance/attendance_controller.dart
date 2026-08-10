import 'dart:async';
import 'dart:io' show Platform;

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
import '../home/controllers/home_controller.dart';
import 'widgets/clock_dialogs.dart';

/// Geofence state for the attendance screen's map + clock gate.
///
/// `anywhere` is WFA: a position was resolved and an office may even be named,
/// but the tenant policy does not hold the employee to any radius.
enum GeoState {
  loading,
  inside,
  outside,
  anywhere,
  gpsOff,
  denied,
  noOffice,
  error,
}

class AttendanceController extends GetxController with WidgetsBindingObserver {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final isClocking = false.obs;
  final loadFailed = false.obs;
  final today = Rxn<AttendanceToday>();
  late final Worker _queueWorker;

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

  /// Seconds the current detection has been running, so the chip can count a
  /// slow fix out loud rather than look stuck.
  final locatingSeconds = 0.obs;

  /// The reported margin of error on the current fix, in metres.
  ///
  /// A geofence of a hundred metres cannot be judged by a fix that is itself
  /// accurate to three thousand: the employee is then told they are kilometres
  /// from an office they are standing in. Kept so the screen can say so.
  final fixAccuracyMeters = 0.0.obs;

  /// iOS 14+ only: the employee granted "Approximate Location" and declined to
  /// upgrade. Every fix from here on can be kilometres off, by design.
  final isReducedAccuracy = false.obs;

  /// Matches the key inside `NSLocationTemporaryUsageDescriptionDictionary`
  /// in ios/Runner/Info.plist. iOS refuses the upgrade prompt without it.
  static const _preciseLocationPurposeKey = 'AbsensiPresisi';

  /// Whether the one-per-run precision prompt has already been shown.
  bool _askedForPreciseLocation = false;

  /// The server's own rule, mirrored — see `AttendanceController::geofenceCheck`.
  ///
  /// Every punch needs a fix, WFA and WFH included: the server refuses a clock
  /// without coordinates, because the mock-location check has nothing to read
  /// without them. Beyond that, WFH (approved) and WFA answer to no office,
  /// while every other scope has to land inside a radius.
  ///
  /// Opening the gate on an unknown location would only move the refusal later,
  /// to a 422 the employee earns *after* scanning their face.
  bool get canClockByLocation {
    if (userLat.value == null || userLng.value == null) return false;

    return effectiveWorkMode == 'home' ||
        geoState.value == GeoState.anywhere ||
        geoState.value == GeoState.inside;
  }

  /// Whether the current fix is too coarse to be judged against the office
  /// radius — either iOS is deliberately blurring it, or the reported margin of
  /// error is larger than the geofence itself.
  bool get isCoarseFix {
    if (isReducedAccuracy.value) return true;

    final radius = nearest.value?.radius ?? 0;

    return radius > 0 && fixAccuracyMeters.value > radius;
  }

  /// What to do about a fix too coarse to trust. Same diagnosis on both
  /// platforms; only the settings path differs.
  String get coarseFixAdvice {
    final margin = '±${fixAccuracyMeters.value.round()} m';

    if (isReducedAccuracy.value) {
      return Platform.isIOS
          ? 'Lokasi masih mode perkiraan ($margin). Buka Pengaturan → Privasi '
                '& Keamanan → Layanan Lokasi → AvanaHR, lalu aktifkan '
                '"Lokasi Tepat".'
          : 'Lokasi masih mode perkiraan ($margin). Buka Pengaturan → Aplikasi '
                '→ AvanaHR → Izin → Lokasi, lalu pilih "Gunakan lokasi persis".';
    }

    return 'Akurasi lokasi masih $margin, lebih besar dari radius kantor. '
        'Cari tempat yang lebih terbuka lalu coba lagi.';
  }

  /// Why the clock is shut, in the words the employee can act on. Mirrors the
  /// server's messages so the two never tell different stories.
  String get locationBlockReason {
    if (geoState.value == GeoState.loading) {
      return 'Lokasi masih dideteksi. Tunggu sebentar lalu coba lagi.';
    }

    switch (geoState.value) {
      case GeoState.gpsOff:
        return 'GPS mati. Aktifkan lokasi lalu coba lagi.';
      case GeoState.denied:
        return 'Izin lokasi ditolak. Beri izin lokasi untuk bisa absen.';
      case GeoState.noOffice:
        return 'Lokasi kerja belum diatur admin. Hubungi HR.';
      case GeoState.outside:
        final office = nearest.value?.name ?? 'kantor';
        final base =
            'Di luar radius $office (${distanceMeters.value.round()} m). '
            'Mendekat ke lokasi untuk absen.';

        // A coarse fix is the likelier explanation than an employee who has
        // wandered kilometres off, so say which one the phone is reporting
        // instead of leaving them arguing with the distance.
        return isCoarseFix ? '$base\n$coarseFixAdvice' : base;
      default:
        return 'Lokasi belum terbaca. Periksa GPS lalu coba lagi.';
    }
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    requiresFace.value = _box.read<bool>(_faceKey) ?? false;
    _queueWorker = ever<int>(Get.find<AttendanceQueueService>().revision, (_) {
      load(quiet: true);
      _syncHome();
    });
    load();
    detectLocation();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _queueWorker.dispose();
    super.onClose();
  }

  /// This controller lives for the whole session (bottom-nav tab), so a
  /// forgotten clock-out yesterday would otherwise leave `today` stuck on
  /// yesterday's open record. When the app returns to the foreground on a new
  /// calendar day, re-pull today's attendance so the button resets to a fresh
  /// clock-in instead of continuing the old session.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    // The tab is persistent, so without this the screen keeps answering to the
    // policy that was in force when the app started: an admin who switches the
    // tenant to WFA (or changes the face mode) would not reach an employee who
    // never closed the app. Quiet, so a resume doesn't flash a spinner over a
    // screen that already has its answer.
    load(quiet: !(_isStaleDay || today.value == null));
    detectLocation();
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

  /// [quiet] refreshes in place, without the full-screen spinner — for reloads
  /// the employee did not ask for (a resume, a policy re-check).
  Future<void> load({bool quiet = false}) async {
    isLoading.value = !quiet;
    loadFailed.value = false;
    try {
      today.value = await _api.attendanceToday();
    } catch (_) {
      loadFailed.value = true;
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

  /// How long a single non-interactive step may take. Nothing here is allowed
  /// to run unbounded: a platform channel that never answers used to pin the
  /// screen on [GeoState.loading], which the button reads as "outside radius".
  static const _step = Duration(seconds: 12);

  /// The permission prompt waits on a person, not on a device.
  static const _prompt = Duration(minutes: 2);

  /// The stored fix is meant to be instant — it is read from memory, not from a
  /// radio. Waiting a full step on it only delays the live attempt on the phones
  /// where the platform never answers at all.
  static const _cachedFix = Duration(seconds: 3);

  /// How long the screen keeps listening for a first coordinate.
  ///
  /// A cold receiver indoors regularly needs fifteen seconds or more; giving up
  /// sooner is what leaves an employee reading "Lokasi belum terbaca" while the
  /// phone was seconds away from answering.
  static const _fixBudget = Duration(seconds: 25);

  /// Resolve the nearest office geofence + the user's live position for the
  /// map and the clock gate. Best-effort; never throws, always settles.
  Future<void> detectLocation() async {
    if (isLocating.value) return;
    isLocating.value = true;
    geoState.value = GeoState.loading;
    // A cold fix can take twenty seconds, which reads as a frozen screen unless
    // the wait is counted out loud.
    locatingSeconds.value = 0;
    final tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => locatingSeconds.value++,
    );
    try {
      await _resolveGeofence();
    } catch (_) {
      geoState.value = GeoState.error;
    } finally {
      tick.cancel();
      // A step that timed out leaves the gate unresolved; unknown location must
      // open the gate (the server still validates), never hold it shut.
      if (geoState.value == GeoState.loading) {
        geoState.value = GeoState.error;
      }
      isLocating.value = false;
    }
  }

  Future<void> _resolveGeofence() async {
    // The policy is a fast network round-trip; the fix is the slow half. Asking
    // for them side by side keeps a cold GPS lock off the critical path — done
    // in sequence, the screen waited for the sum of the two.
    final policyRequest = _api.workLocations().timeout(_step);
    final gate = await _permissionGate();

    // A slow or failed policy call used to take the whole detection down with
    // it: the throw left the screen on "Lokasi belum terbaca" even though the
    // GPS was working. The office list only decides which badge to show, so
    // losing it must not cost the employee their coordinates — without offices
    // the fix still lands on the map and the server still rules on the punch.
    WorkLocations? locations;

    try {
      locations = await policyRequest;
    } catch (_) {
      locations = null;
    }

    final isAnywhere = locations?.isAnywhere ?? false;

    // Shown while the fix is still coming, so a WFA employee is not left reading
    // "di luar radius" in the meantime.
    if (isAnywhere) {
      geoState.value = GeoState.anywhere;
    }

    final offices = (locations?.items ?? const <WorkLocationItem>[])
        .where((l) => l.latitude != null && l.longitude != null)
        .toList();

    // No location to be had at all. WFA does not soften this: the server needs
    // coordinates on every punch, so the actionable reason wins over the badge.
    if (gate != null) {
      geoState.value = gate;

      return;
    }

    // The stored fix answers in milliseconds and is usually metres from the
    // truth — good enough to open the gate while the live one is still coming.
    final seed = await _lastKnownPosition();
    if (seed != null) {
      _applyFix(seed, offices, isAnywhere);
    }

    final live = await _livePosition();
    if (live != null) {
      _applyFix(live, offices, isAnywhere);
    } else if (seed == null) {
      geoState.value = GeoState.error;
    }
  }

  /// Place a fix on the map and settle the gate against it.
  void _applyFix(
    Position pos,
    List<WorkLocationItem> offices,
    bool isAnywhere,
  ) {
    userLat.value = pos.latitude;
    userLng.value = pos.longitude;
    fixAccuracyMeters.value = pos.accuracy;

    if (offices.isEmpty) {
      if (!isAnywhere) {
        geoState.value = GeoState.noOffice;
      }

      return;
    }

    WorkLocationItem? closest;
    var closestDistance = double.infinity;
    for (final loc in offices) {
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

    // WFA: the nearest office is only a label here, never a gate.
    if (isAnywhere) return;

    final within = (closest!.radius <= 0) || closestDistance <= closest.radius;
    geoState.value = within ? GeoState.inside : GeoState.outside;
  }

  /// Null when location may be read; otherwise the state that says why not.
  Future<GeoState?> _permissionGate() async {
    if (!await Geolocator.isLocationServiceEnabled().timeout(_step)) {
      return GeoState.gpsOff;
    }

    var permission = await Geolocator.checkPermission().timeout(_step);
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission().timeout(_prompt);
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return GeoState.denied;
    }

    await _ensurePreciseLocation();

    return null;
  }

  /// Establish whether the platform is giving precise coordinates, and on iOS
  /// ask for them when it is not.
  ///
  /// Granting location does not mean granting a usable location. iOS 14+ offers
  /// "Approximate Location" and Android 12+ offers the same choice by granting
  /// only `ACCESS_COARSE_LOCATION`; either way the coordinates that follow are
  /// deliberately blurred by kilometres. Against a hundred-metre geofence that
  /// reads exactly like standing far from an office one is sitting inside — a
  /// permission problem wearing a GPS problem's clothes.
  ///
  /// The detection is identical on both platforms; only the remedy differs.
  /// iOS can raise precision for the session on request, so it is asked;
  /// Android has no such prompt, and the employee is pointed at the permission
  /// screen instead (see [coarseFixAdvice]). Best-effort throughout: a refusal,
  /// or a build whose Info.plist lacks the purpose key, only records the fact
  /// and lets detection continue.
  Future<void> _ensurePreciseLocation() async {
    try {
      var accuracy = await Geolocator.getLocationAccuracy().timeout(_step);

      // Asked at most once per app run. Detection re-runs on every pull, and a
      // system prompt that reappears each time would be worse than the coarse
      // fix it is trying to fix; the advice text carries the rest.
      if (accuracy == LocationAccuracyStatus.reduced &&
          Platform.isIOS &&
          !_askedForPreciseLocation) {
        _askedForPreciseLocation = true;
        accuracy = await Geolocator.requestTemporaryFullAccuracy(
          purposeKey: _preciseLocationPurposeKey,
        ).timeout(_prompt);
      }

      isReducedAccuracy.value = accuracy == LocationAccuracyStatus.reduced;
    } catch (e) {
      debugPrint('[Attendance] precise-location check failed: $e');
    }
  }

  /// The fix the platform already had, if any. Costs nothing to ask.
  Future<Position?> _lastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition().timeout(_cachedFix);
    } catch (_) {
      return null;
    }
  }

  /// A fresh fix: every provider listens at once, and the first coordinate any
  /// of them produces wins.
  ///
  /// This used to be three one-shot attempts in a row, each with its own short
  /// deadline. A phone that would have answered in fourteen seconds returned
  /// nothing after twenty: each attempt threw away the warm-up the one before
  /// it had paid for, and a fused provider that is merely slow looks identical
  /// to one that is broken. Listening instead of asking also means a fix that
  /// arrives early is used early, rather than after the current attempt's timer
  /// runs out.
  ///
  /// The second Android provider goes around Play Services entirely, for the
  /// phones where the fused one never answers at all.
  Future<Position?> _livePosition() async {
    // Both platforms ask for the same grade of fix. `medium` means "within a
    // hundred metres" on either one — the same size as a typical office
    // geofence, so a fix the platform considers good enough is already
    // borderline for the radius it gets judged against. `high` is GPS-grade on
    // Android and ten metres on iOS, for the seconds this screen is open.
    const target = LocationAccuracy.high;

    final providers = <LocationSettings>[
      if (Platform.isAndroid) ...[
        AndroidSettings(accuracy: target),
        AndroidSettings(accuracy: target, forceLocationManager: true),
      ] else
        AppleSettings(accuracy: target),
    ];

    final first = Completer<Position>();
    final streams = <StreamSubscription<Position>>[];

    for (final settings in providers) {
      try {
        streams.add(
          Geolocator.getPositionStream(locationSettings: settings).listen(
            (position) {
              if (!first.isCompleted) first.complete(position);
            },
            // A provider this device does not have must not take the others
            // down with it.
            onError: (_) {},
            cancelOnError: false,
          ),
        );
      } catch (_) {
        // Provider unavailable on this device.
      }
    }

    if (streams.isEmpty) return null;

    try {
      return await first.future.timeout(_fixBudget);
    } catch (_) {
      return null;
    } finally {
      for (final stream in streams) {
        unawaited(stream.cancel());
      }
    }
  }

  /// Marks the caller as face-enrolled locally (used by the on-page scanner
  /// after it enrolls a template server-side).
  void markFaceEnrolled() {
    requiresFace.value = true;
    _box.write(_faceKey, true);
  }

  /// Both clocks are spent for today — there is no action left to offer.
  bool get isDoneToday => today.value?.isDone ?? false;

  /// Whether this tenant makes every punch carry a single-use liveness nonce.
  bool get needsChallenge => today.value?.requiresLivenessChallenge ?? false;

  /// Whether the geofence currently allows clocking; the on-page scanner uses
  /// this to decide whether to run the camera.
  bool get canClockNow =>
      today.value != null &&
      !loadFailed.value &&
      canClockByLocation &&
      !isClocking.value &&
      !isDoneToday;

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
    if (today.value == null || loadFailed.value) {
      AppToast.warning(
        'Status absensi belum tersedia. Muat ulang lalu coba lagi.',
      );

      return;
    }

    // A day may have rolled over while the app sat in memory; refresh first so
    // we never clock out on a new day against yesterday's open record.
    if (_isStaleDay) {
      await load();
    }

    // Clocked in and out already: a third tap has nothing to submit, and the
    // server would only answer 422.
    if (isDoneToday) {
      AppToast.warning('Absensi hari ini sudah selesai.');

      return;
    }

    final type = today.value?.canClockIn ?? true ? 'in' : 'out';

    // Geofence gate, mirroring the server (see canClockByLocation). A stale fix
    // is worth one more attempt before refusing: the employee may have walked
    // into the radius, or turned GPS on, since the screen last looked.
    if (!canClockByLocation) {
      await detectLocation();
    }
    if (!canClockByLocation) {
      AppToast.warning(locationBlockReason);

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
          // Whether a scan that never completed ends the punch is the tenant's
          // call, mirrored from `requirements.face_enforcement`. Under "flag"
          // the server records the punch and marks it for review, so refusing
          // here would be stricter than the policy the tenant chose — and would
          // leave an employee whose camera cannot read their face with no way
          // to clock in at all.
          if (today.value?.blocksOnFaceFailure ?? true) {
            AppToast.warning('Verifikasi wajah dibatalkan.');

            return;
          }

          AppToast.info(
            'Wajah tidak terverifikasi. Absen tetap dicatat dan ditandai '
            'untuk ditinjau HR.',
          );
        } else {
          faceEmbedding = List<double>.from(result['embedding'] as List);
          selfiePath = result['photo'] as String?;
        }
      } else {
        // Not enrolled yet → explain first so the flow is clear, then register.
        // The just-captured template + frame are reused for this same punch.
        final wantEnroll = await confirmFaceEnroll();
        if (!wantEnroll) {
          // Whether backing out ends the punch is the tenant's call. With
          // "wajib daftar wajah" on the server refuses a clock from someone
          // unenrolled, so there is nothing to submit; with it off it accepts
          // the punch and simply skips the identity match, and forcing an
          // enrolment here would be stricter than the policy asks.
          if (today.value?.requiresFaceEnrollment ?? true) {
            return;
          }
        } else {
          final result = await Get.toNamed(Routes.FACE_ENROLL);
          if (result is! Map || result['embedding'] is! List) {
            AppToast.warning('Pendaftaran wajah dibatalkan.');

            // Same rule as backing out of the prompt above: only a tenant that
            // requires enrolment loses the punch over an enrolment that did not
            // finish. Without that requirement the server clocks them in and
            // skips the match, so the app must not refuse on its behalf.
            if (today.value?.requiresFaceEnrollment ?? true) {
              return;
            }
          } else {
            markFaceEnrolled();
            faceEmbedding = List<double>.from(result['embedding'] as List);
            selfiePath = result['photo'] as String?;
          }
        }
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
        // UTC, so the server reads one unambiguous instant no matter what
        // zone the phone is set to.
        'clocked_at': DateTime.now().toUtc().toIso8601String(),
        if (faceEmbedding != null) 'face_embedding': faceEmbedding,
        // A nonce lives two minutes, so a queued punch cannot carry one: the
        // queue fetches its own when it finally reaches the server.
        if (needsChallenge) 'needs_nonce': true,
      };

      // No internet → queue it and reflect the action locally.
      if (!Get.find<ConnectivityService>().online.value) {
        hideClockLoader();
        _queueOffline(type, entry);
        return;
      }

      // Tenants with the liveness challenge on get a single-use nonce per
      // punch; without it the server rejects the clock outright.
      final nonce = needsChallenge ? await _api.attendanceChallenge() : null;

      try {
        final res = await _api.clock(
          nonce: nonce,
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
          _syncHome();
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
      showClockResult(success: false, message: 'Terjadi kesalahan. Coba lagi.');
    } finally {
      isClocking.value = false;
    }
  }

  void _queueOffline(String type, Map<String, dynamic> entry) {
    if (today.value == null) {
      AppToast.warning(
        'Status absensi belum tersedia. Muat ulang lalu coba lagi.',
      );

      return;
    }
    Get.find<AttendanceQueueService>().enqueue({
      ...entry,
      'work_date': today.value?.workDate ?? today.value?.date,
    });
    _applyOptimistic(type);
    // Offline: there is nothing to re-fetch, so hand the home card the same
    // optimistic record this screen is showing.
    _syncHome(optimistic: today.value);
    AppToast.info(
      'Tidak ada internet. Absen disimpan & dikirim otomatis saat online.',
    );
  }

  /// The home tab keeps its own copy of today's attendance and only re-pulls it
  /// on a new day or a pull-to-refresh. Without this nudge its card still reads
  /// "Belum absen masuk" right after a punch made on this screen.
  void _syncHome({AttendanceToday? optimistic}) {
    if (!Get.isRegistered<HomeController>()) {
      return;
    }

    final home = Get.find<HomeController>();
    if (optimistic != null) {
      home.adoptToday(optimistic);

      return;
    }

    home.refreshAttendance();
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
    // The office's clock, not the phone's — otherwise the time shown now
    // disagrees with the one the server sends back.
    final now = today.value?.nowOnTenantClock() ?? DateTime.now();
    final hm =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final t = today.value;
    if (t == null) return;

    if (type == 'in') {
      today.value = t.copyWith(
        nextAction: 'out',
        clockIn: hm,
        clockInAt: now.toIso8601String(),
        workMode: workMode.value,
        pendingSync: true,
      );
    } else {
      today.value = t.copyWith(
        nextAction: 'done',
        clockOut: hm,
        pendingSync: true,
      );
    }
  }

  /// Best-effort GPS for the punch itself; null if permission denied or
  /// location off. Shares the escalating provider chain with the map, so the
  /// coordinate on the record is found the same way the gate found its own.
  Future<Position?> _currentPosition() async {
    try {
      if (await _permissionGate() != null) return null;

      return await _livePosition() ?? await _lastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}
