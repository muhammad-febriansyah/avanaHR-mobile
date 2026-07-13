import 'package:get/get.dart';

import '../../data/models/activity.dart';
import '../../data/providers/avana_api.dart';

/// Backs the "Riwayat" tab: a merged activity feed from `/me/activities`.
class RiwayatController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final items = <ActivityItem>[].obs;
  final typeFilter = 'all'.obs;

  /// Activities narrowed to the selected type ('all' = everything).
  List<ActivityItem> get visibleItems => typeFilter.value == 'all'
      ? items
      : items.where((e) => e.type == typeFilter.value).toList();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      items.value = await _api.activities();
    } catch (_) {
      items.clear();
    }
    isLoading.value = false;
  }
}
