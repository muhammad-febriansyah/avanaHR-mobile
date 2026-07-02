import 'package:get/get.dart';

import '../../data/models/payslip.dart';
import '../../data/providers/avana_api.dart';

class PayslipController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final items = <Payslip>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      items.assignAll(await _api.payslips());
    } catch (_) {
      items.clear();
    }
    isLoading.value = false;
  }
}
