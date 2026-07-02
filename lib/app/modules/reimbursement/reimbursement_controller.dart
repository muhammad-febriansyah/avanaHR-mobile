import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../core/widgets/app_toast.dart';
import '../../data/models/ess_models.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

class ReimbursementController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final submitting = false.obs;
  final items = <ReimbursementItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      items.assignAll(await _api.reimbursements());
    } catch (_) {
      items.clear();
    }
    isLoading.value = false;
  }

  Future<bool> submit({required String category, required int amount}) async {
    submitting.value = true;
    try {
      final res = await _api.submitReimbursement(category: category, amount: amount);
      submitting.value = false;
      if (res.statusCode == 201) {
        AppToast.success('Reimbursement terkirim');
        await load();
        return true;
      }
      AppToast.error(ApiClient.messageFrom(res, 'Gagal mengajukan reimbursement.'));
      return false;
    } on DioException catch (e) {
      submitting.value = false;
      AppToast.error(ApiClient.messageFrom(e.response, 'Gagal terhubung ke server.'));
      return false;
    }
  }
}
