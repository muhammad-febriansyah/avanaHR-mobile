import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../../../data/models/attendance.dart';
import '../../../data/models/dashboard.dart';
import '../../../data/models/ess_models.dart';
import '../../../data/providers/avana_api.dart';
import '../../../data/services/auth_service.dart';
import '../../../routes/app_pages.dart';

/// Result of the home-screen geofence auto-detect.
enum LocState { loading, inside, outside, denied, gpsOff, noOffice, error }

class HomeController extends GetxController {
  final AvanaApi _api = AvanaApi();
  final AuthService auth = Get.find();

  final isLoading = true.obs;
  final today = Rxn<AttendanceToday>();
  final unread = 0.obs;
  final announcements = <AnnouncementItem>[].obs;
  final summary = Rxn<DashboardSummary>();

  // Auto-detected location status.
  final locState = LocState.loading.obs;
  final nearestOffice = ''.obs;
  final distanceMeters = 0.0.obs;

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
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final d = DateTime.now();

    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  void onInit() {
    super.onInit();
    refreshAll();
    detectLocation();
  }

  Future<void> refreshAll() async {
    isLoading.value = true;
    await Future.wait([_loadToday(), _loadUnread(), _loadAnnouncements(), _loadSummary()]);
    isLoading.value = false;
  }

  Future<void> _loadSummary() async {
    try {
      summary.value = await _api.dashboard();
    } catch (_) {
      summary.value = null;
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
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        locState.value = LocState.denied;

        return;
      }

      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
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
        final d = Geolocator.distanceBetween(pos.latitude, pos.longitude, loc.latitude!, loc.longitude!);
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
