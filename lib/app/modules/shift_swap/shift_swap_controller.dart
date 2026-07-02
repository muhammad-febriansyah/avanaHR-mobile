import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../core/widgets/app_toast.dart';
import '../../data/models/ess_models.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

class ShiftSwapController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final submitting = false.obs;
  final items = <ShiftSwapItem>[].obs;
  final colleagues = <Colleague>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final results = await Future.wait([_api.shiftSwaps(), _api.swapColleagues()]);
      items.assignAll(results[0] as List<ShiftSwapItem>);
      colleagues.assignAll(results[1] as List<Colleague>);
    } catch (_) {}
    isLoading.value = false;
  }

  Future<bool> submit({required int targetId, required String date, String? reason}) async {
    submitting.value = true;
    try {
      final res = await _api.submitShiftSwap(targetId: targetId, date: date, reason: reason);
      submitting.value = false;
      if (res.statusCode == 201) {
        AppToast.success('Permintaan tukar shift terkirim');
        await load();
        return true;
      }
      AppToast.error(ApiClient.messageFrom(res, 'Gagal mengajukan tukar shift.'));
      return false;
    } on DioException catch (e) {
      submitting.value = false;
      AppToast.error(ApiClient.errorMessage(e));
      return false;
    }
  }
}
