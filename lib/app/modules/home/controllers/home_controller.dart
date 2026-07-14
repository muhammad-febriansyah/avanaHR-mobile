import 'dart:async';

import 'package:dio/dio.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart' hide Response;

import '../../../core/widgets/app_toast.dart';
import '../../../data/models/attendance.dart';
import '../../../data/models/dashboard.dart';
import '../../../data/models/ess_models.dart';
import '../../../data/providers/api_client.dart';
import '../../../data/providers/avana_api.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../routes/app_pages.dart';
import '../views/mood_dialog.dart';

/// Result of the home-screen geofence auto-detect.
enum LocState { loading, inside, outside, denied, gpsOff, noOffice, error }

class HomeController extends GetxController {
  final AvanaApi _api = AvanaApi();
  final AuthService auth = Get.find();
  final StorageService _storage = Get.find();

  final isLoading = true.obs;
  final today = Rxn<AttendanceToday>();
  final unread = 0.obs;
  final announcements = <AnnouncementItem>[].obs;
  final summary = Rxn<DashboardSummary>();

  // Manager (MSS) summary for the home manager banner.
  final pendingApprovals = 0.obs;
  final teamCount = 0.obs;

  // Daily mood check-in.
  final moodCheckedIn = false.obs;
  final selectedMood = RxnString();
  final moodSubmitting = false.obs;

  // Home/Office work-mode selector on the attendance hero card.
  final workMode = 'office'.obs;

  // Auto-detected location status.
  final locState = LocState.loading.obs;
  final nearestOffice = ''.obs;
  final distanceMeters = 0.0.obs;

  // Realtime user location: a reverse-geocoded street/area label that updates
  // as the user moves, plus the live GPS stream backing it.
  final userAddress = ''.obs;
  final locating = true.obs;
  StreamSubscription<Position>? _posSub;

  String get name => auth.user.value?.name ?? '';
  bool get isManager => auth.isManager;

  /// Time-of-day greeting for the header.
  String get greeting {
    final h = DateTime.now().hour;
    if (h < 11) {
      return 'Selamat Pagi';
    }
    if (h < 15) {
      return 'Selamat Siang';
    }
    if (h < 19) {
      return 'Selamat Sore';
    }

    return 'Selamat Malam';
  }

  /// Indonesian date label, e.g. "Jumat, 3 Jul 2026".
  String get todayLabel {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final d = DateTime.now();

    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// Compact date without the weekday, e.g. "14 Jul 2026" — for tight rows.
  String get todayShort {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final d = DateTime.now();

    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  void onInit() {
    super.onInit();
    refreshAll();
    detectLocation();
    startLocationStream();
  }

  @override
  void onClose() {
    _posSub?.cancel();
    super.onClose();
  }

  /// Streams the user's realtime GPS position and reverse-geocodes it into a
  /// short human address shown in the header. Best-effort; never throws. Only
  /// re-geocodes after the user moves ≥25 m to keep it cheap.
  Future<void> startLocationStream() async {
    locating.value = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        userAddress.value = 'GPS mati';
        locating.value = false;
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        userAddress.value = 'Izin lokasi ditolak';
        locating.value = false;
        return;
      }

      // Seed immediately from the current/last fix so the header isn't empty
      // while waiting for the first stream event.
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        await _reverseGeocode(pos);
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) await _reverseGeocode(last);
      }

      await _posSub?.cancel();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
        ),
      ).listen(_reverseGeocode, onError: (_) {});
    } catch (_) {
      if (userAddress.value.isEmpty) {
        userAddress.value = 'Lokasi tidak tersedia';
      }
    } finally {
      locating.value = false;
    }
  }

  /// Turns a GPS fix into a compact "area, city" label via on-device geocoding.
  Future<void> _reverseGeocode(Position pos) async {
    locating.value = false;
    try {
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isEmpty) return;
      final p = marks.first;
      final parts = <String?>[
        p.subLocality?.isNotEmpty == true ? p.subLocality : p.thoroughfare,
        p.locality?.isNotEmpty == true ? p.locality : p.subAdministrativeArea,
      ].where((e) => e != null && e.isNotEmpty).cast<String>().toList();
      if (parts.isNotEmpty) {
        userAddress.value = parts.join(', ');
      } else if (p.name?.isNotEmpty == true) {
        userAddress.value = p.name!;
      }
    } catch (_) {
      // Geocoder can fail (no network / no result); keep the previous label.
    }
  }

  Future<void> refreshAll() async {
    isLoading.value = true;
    await Future.wait([
      _loadToday(),
      _loadUnread(),
      _loadAnnouncements(),
      _loadSummary(),
      _loadMood(),
      _loadManager(),
    ]);
    isLoading.value = false;
    _maybePromptMood();
  }

  /// Date key (yyyy-MM-dd) for once-per-day gating.
  String _todayStr() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Auto-show the mood popup at most once per calendar day, and only when the
  /// employee hasn't checked in yet today.
  void _maybePromptMood() {
    if (moodCheckedIn.value) return;
    if (Get.isDialogOpen ?? false) return;
    final today = _todayStr();
    if (_storage.moodPromptDate == today) return;
    _storage.setMoodPromptDate(today);
    Get.dialog(const MoodDialog());
  }

  /// Manual open (from the "Feeling" quick action) — always allowed.
  void openMoodDialog() {
    if (Get.isDialogOpen ?? false) return;
    Get.dialog(const MoodDialog());
  }

  Future<void> _loadMood() async {
    try {
      final res = await _api.moodToday();
      final data = res.data['data'];
      moodCheckedIn.value = (data?['checked_in'] as bool?) ?? false;
      selectedMood.value = data?['mood'] as String?;
    } catch (_) {
      // Non-fatal.
    }
  }

  Future<void> submitMood(String mood) async {
    moodSubmitting.value = true;
    try {
      final res = await _api.submitMood(mood);
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        selectedMood.value = mood;
        moodCheckedIn.value = true;
        // Also mark today as prompted so the popup can't reappear today even if
        // a later /me/mood reload fails (network) and loses the checked-in flag.
        _storage.setMoodPromptDate(_todayStr());
        AppToast.success(
          ApiClient.messageFrom(res, 'Terima kasih, perasaanmu tercatat.'),
        );
      } else {
        AppToast.error(ApiClient.messageFrom(res, 'Gagal menyimpan perasaan.'));
      }
    } on DioException catch (e) {
      AppToast.error(ApiClient.errorMessage(e));
    } finally {
      moodSubmitting.value = false;
    }
  }

  Future<void> _loadSummary() async {
    try {
      summary.value = await _api.dashboard();
    } catch (_) {
      summary.value = null;
    }
  }

  /// Team approval + headcount counts for the manager banner. Only fetched for
  /// managers; failures are non-fatal (the banner still shows without counts).
  Future<void> _loadManager() async {
    if (!isManager) {
      return;
    }
    try {
      final results = await Future.wait([_api.approvals(), _api.team()]);
      pendingApprovals.value = results[0].length;
      teamCount.value = results[1].length;
    } catch (_) {
      // Non-fatal.
    }
  }

  /// Auto-detect whether the employee is inside an office geofence, for the
  /// home location card. Best-effort; never throws.
  Future<void> detectLocation() async {
    locState.value = LocState.loading;
    try {
      final locations = await _api.workLocations();
      if (locations.isEmpty) {
        locState.value = LocState.noOffice;

        return;
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        locState.value = LocState.gpsOff;

        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        locState.value = LocState.denied;

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
        // Emulators / slow fixes: fall back to the last known position.
        final last = await Geolocator.getLastKnownPosition();
        if (last == null) {
          locState.value = LocState.error;

          return;
        }
        pos = last;
      }

      WorkLocationItem? nearest;
      var nearestDistance = double.infinity;
      for (final loc in locations) {
        if (loc.latitude == null || loc.longitude == null) {
          continue;
        }
        final d = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          loc.latitude!,
          loc.longitude!,
        );
        if (d < nearestDistance) {
          nearestDistance = d;
          nearest = loc;
        }
      }

      if (nearest == null) {
        locState.value = LocState.noOffice;

        return;
      }

      nearestOffice.value = nearest.name;
      distanceMeters.value = nearestDistance;
      final within = nearest.radius <= 0 || nearestDistance <= nearest.radius;
      locState.value = within ? LocState.inside : LocState.outside;
    } catch (_) {
      locState.value = LocState.error;
    }
  }

  Future<void> _loadAnnouncements() async {
    try {
      announcements.value = (await _api.announcements()).take(3).toList();
    } catch (_) {
      announcements.clear();
    }
  }

  Future<void> _loadToday() async {
    try {
      today.value = await _api.attendanceToday();
    } catch (_) {
      today.value = null;
    }
  }

  Future<void> _loadUnread() async {
    try {
      unread.value = (await _api.notifications()).unread;
    } catch (_) {
      unread.value = 0;
    }
  }

  Future<void> logout() async {
    await auth.logout();
    Get.offAllNamed(Routes.LOGIN);
  }
}
