import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../core/widgets/app_toast.dart';
import '../../data/models/ess_models.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

class AttendanceCorrectionController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final submitting = false.obs;
  final items = <AttendanceCorrectionItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      items.assignAll(await _api.attendanceCorrections());
    } catch (_) {
      items.clear();
    }
    isLoading.value = false;
  }

  Future<bool> submit({
    required String date,
    String? clockIn,
    String? clockOut,
    required String reason,
  }) async {
    submitting.value = true;
    try {
      final res = await _api.submitCorrection(
        date: date,
        clockIn: clockIn,
        clockOut: clockOut,
        reason: reason,
      );
      submitting.value = false;
      if (res.statusCode == 201) {
        AppToast.success('Pengajuan koreksi absen terkirim');
        await load();
        return true;
      }
      AppToast.error(ApiClient.messageFrom(res, 'Gagal mengajukan koreksi.'));
      return false;
    } on DioException catch (e) {
      submitting.value = false;
      AppToast.error(ApiClient.messageFrom(e.response, 'Gagal terhubung ke server.'));
      return false;
    }
  }
}
