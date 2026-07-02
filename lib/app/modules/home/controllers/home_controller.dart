import 'package:get/get.dart';

import '../../../data/models/attendance.dart';
import '../../../data/models/ess_models.dart';
import '../../../data/providers/avana_api.dart';
import '../../../data/services/auth_service.dart';
import '../../../routes/app_pages.dart';

class HomeController extends GetxController {
  final AvanaApi _api = AvanaApi();
  final AuthService auth = Get.find();

  final isLoading = true.obs;
  final today = Rxn<AttendanceToday>();
  final unread = 0.obs;
  final announcements = <AnnouncementItem>[].obs;

  String get name => auth.user.value?.name ?? '';
  bool get isManager => auth.isManager;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
  }

  Future<void> refreshAll() async {
    isLoading.value = true;
    await Future.wait([_loadToday(), _loadUnread(), _loadAnnouncements()]);
    isLoading.value = false;
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
