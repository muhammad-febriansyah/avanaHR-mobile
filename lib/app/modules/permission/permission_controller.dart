import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../core/widgets/app_toast.dart';
import '../../core/widgets/filter_chips.dart';
import '../../data/models/ess_models.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

class PermissionController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final submitting = false.obs;
  final items = <PermissionItem>[].obs;
  final statusFilter = 'all'.obs;

  /// Items narrowed to the selected status group ('all' = everything).
  List<PermissionItem> get visibleItems => statusFilter.value == 'all'
      ? items
      : items
            .where((e) => statusGroup(e.status) == statusFilter.value)
            .toList();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      items.assignAll(await _api.permissions());
    } catch (_) {
      items.clear();
    }
    isLoading.value = false;
  }

  Future<bool> submit({
    required String startDate,
    required String endDate,
    required String type,
    String? startTime,
    String? endTime,
    String? reason,
  }) async {
    submitting.value = true;
    try {
      final res = await _api.submitPermission(
        startDate: startDate,
        endDate: endDate,
        type: type,
        startTime: startTime,
        endTime: endTime,
        reason: reason,
      );
      submitting.value = false;
      if (res.statusCode == 201) {
        AppToast.success('Pengajuan izin terkirim');
        await load();
        return true;
      }
      AppToast.error(ApiClient.messageFrom(res, 'Gagal mengajukan izin.'));
      return false;
    } on DioException catch (e) {
      submitting.value = false;
      AppToast.error(
        ApiClient.messageFrom(e.response, 'Gagal terhubung ke server.'),
      );
      return false;
    }
  }
}
