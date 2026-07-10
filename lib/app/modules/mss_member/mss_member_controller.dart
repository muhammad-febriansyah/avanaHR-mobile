import 'package:get/get.dart';

import '../../data/models/mss.dart';
import '../../data/providers/avana_api.dart';

class MssMemberController extends GetxController {
  final AvanaApi _api = AvanaApi();

  /// The roster member tapped from the Tim tab (used for the header before the
  /// detail loads).
  final MssTeamMember member;

  MssMemberController(this.member);

  final isLoading = true.obs;
  final detail = Rxn<MssMemberDetail>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      detail.value = await _api.mssMember(member.id);
    } catch (_) {
      // keep header from the passed member
    }
    isLoading.value = false;
  }
}
