import 'package:get/get.dart';

import '../../core/widgets/app_toast.dart';
import '../../data/models/app_notification.dart';
import '../../data/providers/avana_api.dart';
import '../home/controllers/home_controller.dart';

class NotificationController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final items = <AppNotification>[].obs;
  final unread = 0.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final res = await _api.notifications();
      items.assignAll(res.items);
      unread.value = res.unread;
    } catch (_) {
      items.clear();
    }
    isLoading.value = false;
    _syncHomeBadge();
  }

  /// Mark a single notification read when tapped. Flips it locally first so the
  /// tap feels instant, then persists; re-syncs from the server on failure.
  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    final i = items.indexWhere((e) => e.id == n.id);
    if (i == -1) return;

    items[i] = n.copyWith(isRead: true);
    if (unread.value > 0) unread.value -= 1;
    _syncHomeBadge();

    try {
      await _api.readNotification(n.id);
    } catch (_) {
      await load();
    }
  }

  Future<void> markAllRead() async {
    if (unread.value == 0) return;
    try {
      await _api.readAllNotifications();
      AppToast.success('Semua notifikasi ditandai dibaca.');
      await load();
    } catch (_) {
      AppToast.error('Gagal memperbarui notifikasi.');
    }
  }

  /// The home tab keeps its own bell-badge count, so push our unread total to it
  /// whenever it changes — otherwise the badge only updates on a manual refresh.
  void _syncHomeBadge() {
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().unread.value = unread.value;
    }
  }
}
