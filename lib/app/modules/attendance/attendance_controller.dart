import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, Platform;

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';

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
import '../../data/services/tracking_service.dart';
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
  serverValidation,
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
  Timer? _locationRetryTimer;

  /// Where the employee says they are working from: 'office' or 'home'.
  /// 'home' is only offered — and only accepted by the server — on a day an
  /// approved WFH request covers.
  final workMode = 'office'.obs;

  /// Whether picking "home" is legal today.
  bool get canWorkFromHome => today.value?.wfhApprovedToday ?? false;

  /// Clocking out must stay in the mode the day was clocked in under.
  String get effectiveWorkMode => today.value?.workMode ?? workMode.value;

  /// Whether today's face policy can only be satisfied with a live server.
  ///
  /// Recognition runs behind Laravel, and so does enrolment; a tenant that
  /// blocks the punch when the face check fails cannot have that check skipped
  /// either. Under any of those the punch simply cannot be made offline.
  /// Read by both [clock] and the view, so the button's state and what
  /// tapping it actually does can never disagree.
  bool get requiresOnlineFace =>
      faceNeedsNetwork(today.value, isEnrolled: requiresFace.value);

  /// The rule itself, free of the controller so it can be tested against a
  /// policy without a live connectivity plugin — the same reason
  /// [locationGateAllows] is a static.
  ///
  /// Recognition does NOT need a live connection: the scan runs entirely on the
  /// phone and the photo travels with the queued punch, so the server matches
  /// it when the punch finally arrives. What happens if it does not match is
  /// the tenant's existing `face_enforcement` call — reject (block) or accept
  /// and flag — and that decision belongs on the server either way. Only two
  /// things genuinely cannot be done without a network:
  ///
  ///  * enrolling a face, because the template is stored server-side — so an
  ///    employee who has never enrolled has nothing to be matched against;
  ///  * a liveness challenge, whose nonce has to be minted live to mean
  ///    anything. Fetching one later, at sync, would prove nothing about when
  ///    the punch was made.
  ///
  /// A null day is the app's cold start, before the policy has been fetched;
  /// it is treated as strict so an unknown tenant is never handed a looser gate
  /// than it configured.
  static bool faceNeedsNetwork(
    AttendanceToday? day, {
    required bool isEnrolled,
  }) {
    if (day == null) return true;
    if (day.requiresLivenessChallenge) return true;
    if (!day.requiresFaceCapture) return false;

    // Enrolment is only in the way while the employee has not done it yet.
    return !isEnrolled && day.requiresFaceEnrollment;
  }

  /// Whether a punch made right now would be stored on the phone and sent
  /// later. False when there is a connection (it goes straight out) and false
  /// when the face policy forbids an offline punch altogether.
  bool get queuesOffline => queuesWhileOffline(
    status: Get.find<ConnectivityService>().status.value,
    requiresOnlineFace: requiresOnlineFace,
  );

  static bool queuesWhileOffline({
    required ConnStatus status,
    required bool requiresOnlineFace,
  }) => status != ConnStatus.online && !requiresOnlineFace;

  /// Why the clock is shut while offline, or null when being offline is no
  /// obstacle. Phrased for the tenant's actual face policy rather than a
  /// blanket "no internet".
  String? get offlineBlockReason => offlineBlockMessage(
    status: Get.find<ConnectivityService>().status.value,
    day: today.value,
    isEnrolled: requiresFace.value,
  );

  /// Why the clock is shut while offline, or null when being offline is no
  /// obstacle. Names the actual obstacle: "verifikasi wajah butuh koneksi" was
  /// true of every tenant when recognition was thought to need the network, and
  /// is now misleading — the scan itself runs on the phone.
  static String? offlineBlockMessage({
    required ConnStatus status,
    required AttendanceToday? day,
    required bool isEnrolled,
  }) {
    if (status == ConnStatus.online) return null;
    if (!faceNeedsNetwork(day, isEnrolled: isEnrolled)) return null;

    // "Unstable" is a live interface with no route out — telling that employee
    // there is "no internet" sends them looking for a wifi bar that is already
    // full.
    final connection = status == ConnStatus.unstable
        ? 'Internet tidak stabil'
        : 'Tidak ada internet';

    if (day == null) {
      return '$connection. Status absensi belum termuat — buka lagi saat online.';
    }

    if (day.requiresLivenessChallenge) {
      return '$connection. Absen di kantor ini butuh verifikasi langsung ke server.';
    }

    return '$connection. Daftarkan wajah dulu saat online, setelah itu absen '
        'bisa dilakukan offline.';
  }

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
  Position? _freshPosition;

  /// Run counter for [detectLocation]. A detection abandoned by the watchdog
  /// must not settle state a newer run has since replaced.
  int _locateRun = 0;
  DateTime? _locateStartedAt;

  /// Whether the retry dialog has already been offered for the current failure.
  /// Cleared as soon as a detection succeeds, so the next failure may speak.
  bool _locationPromptShown = false;

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
    return locationGateAllows(
      state: geoState.value,
      hasCoordinates: userLat.value != null && userLng.value != null,
      worksFromHome: effectiveWorkMode == 'home',
      queuesOffline: queuesOffline,
    );
  }

  /// Keep the client gate strict when GPS itself failed, while allowing the
  /// server to make the final geofence decision when only the policy request
  /// failed. Every punch still carries coordinates and the API validates them.
  static bool locationGateAllows({
    required GeoState state,
    required bool hasCoordinates,
    required bool worksFromHome,
    bool queuesOffline = false,
  }) {
    // No fix at all. Online that is a dead end — the server refuses the punch
    // and the employee gains nothing by tapping. Offline it is the normal case:
    // a phone with no data often cannot resolve a position either, and holding
    // the clock shut over it costs the employee the punch itself. Such a punch
    // is queued without coordinates, the queue fills them in when the network
    // returns, and the server records it flagged `location_deferred` instead of
    // measuring a radius against a fix that does not exist.
    if (!hasCoordinates) return queuesOffline;

    return worksFromHome ||
        state == GeoState.anywhere ||
        state == GeoState.inside ||
        state == GeoState.serverValidation;
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
      case GeoState.serverValidation:
        return 'Lokasi sudah ditemukan. Radius akan diperiksa saat absen.';
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
    _locationRetryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!isLocating.value &&
          (geoState.value == GeoState.error ||
              geoState.value == GeoState.gpsOff ||
              geoState.value == GeoState.serverValidation)) {
        detectLocation();
      }
    });
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _queueWorker.dispose();
    _locationRetryTimer?.cancel();
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
      _cacheToday(today.value!);
    } catch (_) {
      final cached = _readCachedToday();
      final current = today.value;
      final fallback = current != null && current.date == _localToday()
          ? current
          : cached;
      if (fallback != null && fallback.date == _localToday()) {
        final pending = Get.find<AttendanceQueueService>().pendingCount.value;
        today.value = fallback.copyWith(pendingSync: pending > 0);
        loadFailed.value = false;
      } else {
        loadFailed.value = true;
      }
    }
    isLoading.value = false;

    // An approval can be revoked, or the day can roll over, while the selector
    // still says "home" — never leave a choice the server would now reject.
    if (!canWorkFromHome) {
      workMode.value = 'office';
    }

    _refreshFaceRequirement();
  }

  String? get _attendanceCacheKey {
    final user = Get.find<AuthService>().user.value;
    if (user == null) return null;
    return 'attendance_today_cache_${user.tenantId ?? 'unknown'}_${user.id}';
  }

  void _cacheToday(AttendanceToday record) {
    final key = _attendanceCacheKey;
    if (key != null) _box.write(key, jsonEncode(record.toCacheJson()));
  }

  AttendanceToday? _readCachedToday() {
    final key = _attendanceCacheKey;
    final raw = key == null ? null : _box.read<String>(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final requirements = json['requirements'];
      return AttendanceToday.fromJson(
        json,
        requirements: requirements is Map
            ? Map<String, dynamic>.from(requirements)
            : const {},
      );
    } catch (_) {
      return null;
    }
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
  static const _fixBudget = Duration(seconds: 10);

  /// The longest a single detection may live.
  ///
  /// Every step inside is bounded, but a platform channel that never answers is
  /// not: one hung call used to leave [isLocating] true forever, and from then
  /// on the refresh button, the retry timer and a pull all returned at the
  /// guard below without doing anything. Restarting the app was the only way
  /// back — which is exactly what employees were doing.
  static const _detectionBudget = Duration(seconds: 45);

  /// Whether the detection in flight has outlived its budget and may be
  /// abandoned by a new one.
  bool get _detectionIsStuck {
    final started = _locateStartedAt;

    return started == null ||
        DateTime.now().difference(started) > _detectionBudget;
  }

  /// Resolve the nearest office geofence + the user's live position for the
  /// map and the clock gate. Best-effort; never throws, always settles.
  ///
  /// [userAsked] marks a retry the employee triggered themselves (the chip's
  /// refresh, the dialog's "Coba Lagi"), which suppresses nothing but tells the
  /// failure path who is already watching.
  Future<void> detectLocation({bool userAsked = false}) async {
    if (isLocating.value && !_detectionIsStuck) return;

    final run = ++_locateRun;
    _locateStartedAt = DateTime.now();
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
      await _resolveGeofence(run).timeout(_detectionBudget);
    } catch (_) {
      if (run == _locateRun) geoState.value = GeoState.error;
    } finally {
      tick.cancel();
      // A run the watchdog abandoned no longer owns the screen: whatever
      // replaced it is the one allowed to settle the state.
      if (run == _locateRun) {
        // A step that timed out leaves the gate unresolved; unknown location
        // must open the gate (the server still validates), never hold it shut.
        if (geoState.value == GeoState.loading) {
          geoState.value = GeoState.error;
        }
        isLocating.value = false;
        _locateStartedAt = null;
        _offerLocationRetry(userAsked: userAsked);
      }
    }
  }

  /// Whether detection ended with nothing the employee can act on.
  bool get _locationUnresolved =>
      userLat.value == null ||
      geoState.value == GeoState.gpsOff ||
      geoState.value == GeoState.denied;

  /// Put the retry dialog on screen when detection came back empty.
  ///
  /// The screen already carried a refresh button, but a failure that only ever
  /// showed up as a grey chip read as "still loading": employees waited, then
  /// killed the app, because a cold start was the one thing that visibly
  /// retried. The dialog says what went wrong and offers the retry directly.
  void _offerLocationRetry({required bool userAsked}) {
    if (!_locationUnresolved) {
      _locationPromptShown = false;

      return;
    }

    // The employee is already looking at the answer: the chip spins for their
    // own refresh, and the dialog they retried from is still open.
    if (userAsked || _locationPromptShown) return;
    // Never over the face scanner, the punch loader or a result card.
    if (isClocking.value || (Get.isDialogOpen ?? false)) return;
    if (Get.currentRoute != Routes.ATTENDANCE) return;

    _locationPromptShown = true;
    unawaited(
      showLocationRetryDialog(
        reason: () => locationRetryReason,
        onRetry: retryLocation,
        onOpenSettings: _locationSettingsAction,
      ),
    );
  }

  /// What the retry dialog says, including what being offline changes.
  String get locationRetryReason {
    final base = locationBlockReason;

    // Offline the punch is no longer waiting on a fix — saying only "lokasi
    // belum terbaca" would read as a refusal on a screen that will happily
    // queue the clock.
    if (queuesOffline) {
      return '$base\n\nTanpa internet absen tetap bisa dilakukan — lokasi '
          'akan diisi otomatis saat koneksi pulih.';
    }

    return base;
  }

  /// Re-run detection for the dialog. True once a coordinate is in hand.
  Future<bool> retryLocation() async {
    await detectLocation(userAsked: true);

    return !_locationUnresolved;
  }

  /// The settings screen that can fix the current failure, or null when the
  /// phone's settings have nothing to do with it.
  Future<void> Function()? get _locationSettingsAction {
    switch (geoState.value) {
      case GeoState.gpsOff:
        return () => Geolocator.openLocationSettings();
      case GeoState.denied:
        return () => Geolocator.openAppSettings();
      default:
        return null;
    }
  }

  /// [run] is the [detectLocation] run this belongs to; a run the watchdog has
  /// already abandoned stops writing to the screen the moment a newer one owns
  /// it, or a hung provider answering minutes late would overwrite a fix that
  /// is currently on the map.
  Future<void> _resolveGeofence(int run) async {
    // The permission gate can sit on a system dialog for as long as a person
    // takes to read it. The policy request therefore starts *after* it, never
    // alongside: a twelve-second deadline that begins while an employee is
    // still deciding whether to grant location expires before they answer, and
    // the office list is then lost to a timeout that had nothing to do with the
    // network. It still overlaps the slow half — the GPS lock below — which is
    // what keeps a cold fix off the critical path.
    final gate = await _permissionGate();

    if (run != _locateRun) return;

    if (gate != null) {
      geoState.value = gate;

      return;
    }

    // Network policy, cached coordinates, and a fresh GPS fix are independent.
    // Start all three together so a slow endpoint is not added in front of a
    // cold GPS lock (previously the waits could total roughly 25 seconds).
    final policyRequest = _api.workLocations().timeout(_step);
    final seedRequest = _lastKnownPosition();
    final liveRequest = _livePosition();

    // A slow or failed policy call used to take the whole detection down with
    // it: the throw left the screen on "Lokasi belum terbaca" even though the
    // GPS was working. The office list only decides which badge to show, so
    // losing it must not cost the employee their coordinates — without offices
    // the fix still lands on the map and the server still rules on the punch.
    WorkLocations? locations;

    final seed = await seedRequest;
    final live = await liveRequest;

    if (run != _locateRun) return;

    if (live != null) {
      // Do not keep the screen in a spinner while the office list is loading.
      // The server remains the authority for the final geofence decision.
      _recordFix(live, fresh: true);
      geoState.value = GeoState.serverValidation;
    }

    // GPS must not wait behind a slow office-policy endpoint. A live fix is
    // useful immediately; the policy is applied as soon as its request ends.
    try {
      locations = await policyRequest;
    } catch (_) {
      locations = null;
    }

    if (run != _locateRun) return;

    final isAnywhere = locations?.isAnywhere ?? false;
    final offices = (locations?.items ?? const <WorkLocationItem>[])
        .where((l) => l.latitude != null && l.longitude != null)
        .toList();
    final fix = live ?? seed;

    if (fix != null && locations != null) {
      if (isAnywhere) geoState.value = GeoState.anywhere;
      _applyFix(fix, offices, isAnywhere, settleGate: live != null);
      if (live == null) geoState.value = GeoState.error;
    } else if (live != null) {
      _recordFix(live, fresh: true);
      // GPS succeeded but the policy endpoint did not. Let the server validate
      // the radius when the punch is submitted.
      geoState.value = GeoState.serverValidation;
    } else if (seed == null) {
      geoState.value = GeoState.error;
    } else if (locations == null) {
      _recordFix(seed);
      geoState.value = GeoState.error;
    }
  }

  void _recordFix(Position pos, {bool fresh = false}) {
    userLat.value = pos.latitude;
    userLng.value = pos.longitude;
    fixAccuracyMeters.value = pos.accuracy;
    if (fresh) _freshPosition = pos;
  }

  /// Place a fix on the map and, when [settleGate] is true, settle the geofence
  /// gate against it. [settleGate] is false for a fast cached seed (it should
  /// not open or close the gate on stale coordinates) and true for a live fix.
  void _applyFix(
    Position pos,
    List<WorkLocationItem> offices,
    bool isAnywhere, {
    bool settleGate = true,
  }) {
    _recordFix(pos, fresh: settleGate);

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
    if (isAnywhere || !settleGate) return;

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
      // A few Android devices do not emit the first stream event until the
      // activity is recreated. A one-shot request gives those devices a direct
      // path to the fused/location-manager provider.
      unawaited(() async {
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: settings,
          );
          if (!first.isCompleted) first.complete(position);
        } catch (_) {
          // The stream provider below may still be available.
        }
      }());
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

  /// Clears the local face flag immediately after the server removes the
  /// caller's biometric template.
  void markFaceDeleted() {
    requiresFace.value = false;
    _box.write(_faceKey, false);
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

  Future<void> clock() => _runClock();

  Future<void> _runClock() async {
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
      // Their own tap is the retry, so the failure answers with the toast
      // below rather than a dialog on top of it.
      await detectLocation(userAsked: true);
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
    // run enrollment (active liveness) first, then clock. Recognition itself
    // runs behind Laravel, so strict face modes require a network connection.
    final requiresFaceCapture = today.value?.requiresFaceCapture ?? true;
    final blockedOffline = offlineBlockReason;
    if (blockedOffline != null) {
      AppToast.warning(blockedOffline);
      return;
    }

    String? selfiePath;
    if (requiresFaceCapture) {
      if (requiresFace.value) {
        final result = await Get.toNamed(Routes.FACE_VERIFY);
        if (result is! Map || result['photo'] is! String) {
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
          selfiePath = result['photo'] as String?;
        }
      } else {
        // Not enrolled yet → explain first so the flow is clear, then register.
        // The just-captured template + frame are reused for this same punch.
        final mandatory =
            (today.value?.requiresFaceEnrollment ?? true) ||
            today.value?.faceMode == 'recognition';
        final wantEnroll = await confirmFaceEnroll(mandatory: mandatory);
        if (!wantEnroll) {
          // Whether backing out ends the punch is the tenant's call. With
          // "wajib daftar wajah" on the server refuses a clock from someone
          // unenrolled, so there is nothing to submit; with it off it accepts
          // the punch and simply skips the identity match, and forcing an
          // enrolment here would be stricter than the policy asks.
          if (mandatory) {
            return;
          }
        } else {
          final result = await Get.toNamed(Routes.FACE_ENROLL);
          if (result is! Map || result['photo'] is! String) {
            AppToast.warning('Pendaftaran wajah dibatalkan.');

            // Same rule as backing out of the prompt above.
            if (mandatory) {
              return;
            }
          } else {
            markFaceEnrolled();
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
      // onto it before upload. Laravel verifies this same accepted frame with
      // the private Python service and stores it as the attendance selfie.
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
          logoUrl: me?.tenantLogoUrl,
        );
      }

      final entry = <String, dynamic>{
        'type': type,
        'work_mode': effectiveWorkMode,
        // Carried so a queued punch can still be identified. The scan happened
        // on the phone; only the match needs the server, and it gets the same
        // frame whenever the punch finally arrives.
        'selfie_path': selfiePath,
        'latitude': pos?.latitude,
        'longitude': pos?.longitude,
        // No fix at punch time. The queue tries again when the network is back
        // and sends whatever it finds flagged, so the server records the punch
        // without measuring a sync-time coordinate against an office radius.
        'location_deferred': pos == null,
        'device_id': device.deviceId,
        // The rest of the device's identity travels too, so the face log can
        // say which phone a punch was matched (or refused) on. Without it the
        // server-side rows carry a score and no idea what produced it.
        'platform': device.platform,
        'os_version': device.osVersion,
        'device_model': device.model,
        'app_version': device.appVersion,
        'is_mock_location': pos?.isMocked ?? false,
        'is_rooted': isRooted,
        'is_emulator': isEmulator,
        // UTC, so the server reads one unambiguous instant no matter what
        // zone the phone is set to.
        'clocked_at': DateTime.now().toUtc().toIso8601String(),
        // A nonce lives two minutes, so a queued punch cannot carry one: the
        // queue fetches its own when it finally reaches the server.
        if (needsChallenge) 'needs_nonce': true,
      };

      // No internet → queue it and reflect the action locally.
      if (!Get.find<ConnectivityService>().online.value) {
        hideClockLoader();
        if (requiresOnlineFace) {
          showClockResult(
            success: false,
            message: 'Koneksi terputus sebelum wajah dapat diverifikasi.',
          );
        } else {
          await _queueOffline(type, entry);
        }
        return;
      }

      // Tenants with the liveness challenge on get a single-use nonce per
      // punch; without it the server rejects the clock outright.
      final nonce = needsChallenge ? await _api.attendanceChallenge() : null;

      try {
        final tracking = Get.find<TrackingService>();
        if (type == 'out') await tracking.prepareClockOut();
        final res = await _api.clock(
          nonce: nonce,
          type: type,
          workMode: effectiveWorkMode,
          latitude: pos?.latitude,
          longitude: pos?.longitude,
          deviceId: device.deviceId,
          isMockLocation: pos?.isMocked ?? false,
          isRooted: isRooted,
          isEmulator: isEmulator,
          selfiePath: selfiePath,
        );
        hideClockLoader();
        final code = res.statusCode ?? 0;
        if (code >= 200 && code < 300) {
          await tracking.handleClockResponse(type, res);
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
        if (ApiClient.isOffline(e)) {
          if (requiresOnlineFace) {
            showClockResult(
              success: false,
              message: 'Koneksi terputus saat memverifikasi wajah.',
            );
          } else {
            await _queueOffline(type, entry);
          }
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

  Future<void> _queueOffline(String type, Map<String, dynamic> entry) async {
    if (today.value == null) {
      AppToast.warning(
        'Status absensi belum tersedia. Muat ulang lalu coba lagi.',
      );

      return;
    }

    // The scan lands in a cache directory the OS is free to empty whenever it
    // wants space. A punch may sit in the queue for days, so the frame is moved
    // somewhere the system will not reclaim before it has been sent.
    final selfiePath = entry['selfie_path'] as String?;
    final storedSelfie = selfiePath == null
        ? null
        : await _persistSelfie(selfiePath);

    Get.find<AttendanceQueueService>().enqueue({
      ...entry,
      'selfie_path': storedSelfie,
      'work_date': today.value?.workDate ?? today.value?.date,
    });
    final tracking = Get.find<TrackingService>();
    if (type == 'in') {
      unawaited(tracking.startPendingClockIn());
    } else {
      unawaited(tracking.stopForPendingClockOut());
    }
    _applyOptimistic(type);
    // Offline: there is nothing to re-fetch, so hand the home card the same
    // optimistic record this screen is showing.
    _syncHome(optimistic: today.value);
    AppToast.info(
      entry['location_deferred'] == true
          ? 'Tidak ada internet & lokasi belum terbaca. Absen disimpan; '
                'lokasi diisi otomatis saat koneksi pulih.'
          : 'Tidak ada internet. Absen disimpan & dikirim otomatis saat online.',
    );
  }

  /// Move a just-captured selfie into the app's documents directory and return
  /// its new path, or null when the copy fails — a punch is worth more than its
  /// photo, so a failed copy queues the punch without one rather than losing it.
  Future<String?> _persistSelfie(String path) async {
    try {
      final source = File(path);
      if (!await source.exists()) return null;

      final dir = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/attendance_queue',
      );
      await dir.create(recursive: true);

      // Keep the original extension so the upload still declares a real image
      // type; anything unexpected falls back to .jpg rather than pulling in a
      // path package for one substring.
      final dot = path.lastIndexOf('.');
      final extension = dot > path.lastIndexOf('/') && dot != -1
          ? path.substring(dot)
          : '.jpg';
      final name = 'punch_${DateTime.now().microsecondsSinceEpoch}$extension';
      final copied = await source.copy('${dir.path}/$name');

      return copied.path;
    } catch (_) {
      return null;
    }
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
    final updated = today.value;
    if (updated != null) _cacheToday(updated);
  }

  /// Best-effort GPS for the punch itself; null if permission denied or
  /// location off. Shares the escalating provider chain with the map, so the
  /// coordinate on the record is found the same way the gate found its own.
  Future<Position?> _currentPosition() async {
    try {
      if (await _permissionGate() != null) return null;

      final fresh = _freshPosition;
      if (fresh != null &&
          DateTime.now().difference(fresh.timestamp).abs() <=
              const Duration(minutes: 2)) {
        return fresh;
      }

      return await _lastKnownPosition() ?? await _livePosition();
    } catch (_) {
      return null;
    }
  }
}
