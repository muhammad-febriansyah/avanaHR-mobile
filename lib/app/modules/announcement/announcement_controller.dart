import 'package:get/get.dart';

import '../../data/models/ess_models.dart';
import '../../data/providers/avana_api.dart';

class AnnouncementController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final items = <AnnouncementItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      items.assignAll(await _api.announcements());
    } catch (_) {
      items.clear();
    }
    isLoading.value = false;
  }
}
