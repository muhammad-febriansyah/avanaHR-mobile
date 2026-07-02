import 'package:get/get.dart';

import '../../core/widgets/app_toast.dart';
import '../../data/models/app_notification.dart';
import '../../data/providers/avana_api.dart';

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
}
