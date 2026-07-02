import 'package:get/get.dart';

import '../../data/models/profile.dart';
import '../../data/providers/avana_api.dart';

class ProfileController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final profile = Rxn<Profile>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      profile.value = await _api.profile();
    } catch (_) {
      profile.value = null;
    }
    isLoading.value = false;
  }
}
