import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../core/widgets/app_toast.dart';
import '../../data/models/ess_models.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

class DokumenController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final submitting = false.obs;
  final items = <DocumentItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      items.assignAll(await _api.documents());
    } catch (_) {}
    isLoading.value = false;
  }

  Future<bool> upload({required String name, String? type, required String filePath}) async {
    submitting.value = true;
    try {
      final res = await _api.submitDocument(name: name, type: type, filePath: filePath);
      submitting.value = false;
      if (res.statusCode == 201) {
        AppToast.success('Dokumen diunggah');
        await load();
        return true;
      }
      AppToast.error(ApiClient.messageFrom(res, 'Gagal mengunggah dokumen.'));
      return false;
    } on DioException catch (e) {
      submitting.value = false;
      AppToast.error(ApiClient.errorMessage(e));
      return false;
    }
  }
}
