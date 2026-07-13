import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../core/widgets/app_toast.dart';
import '../../core/widgets/filter_chips.dart';
import '../../data/models/ess_models.dart';
import '../../data/models/leave_balance.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

class LeaveController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final submitting = false.obs;
  final balances = <LeaveBalance>[].obs;
  final requests = <LeaveRequestItem>[].obs;
  final types = <LeaveType>[].obs;
  final statusFilter = 'all'.obs;

  /// Requests narrowed to the selected status group ('all' = everything).
  List<LeaveRequestItem> get visibleRequests => statusFilter.value == 'all'
      ? requests
      : requests
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
      final results = await Future.wait([
        _api.leaveBalances(),
        _api.leaveRequests(),
        _api.leaveTypes(),
      ]);
      balances.assignAll(results[0] as List<LeaveBalance>);
      requests.assignAll(results[1] as List<LeaveRequestItem>);
      types.assignAll(results[2] as List<LeaveType>);
    } catch (_) {
      // keep whatever loaded
    }
    isLoading.value = false;
  }

  Future<bool> submit({
    required int leaveTypeId,
    required String startDate,
    required String endDate,
    String? reason,
  }) async {
    submitting.value = true;
    try {
      final res = await _api.submitLeave(
        leaveTypeId: leaveTypeId,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
      );
      submitting.value = false;
      if (res.statusCode == 201) {
        AppToast.success('Pengajuan cuti terkirim');
        await load();
        return true;
      }
      AppToast.error(ApiClient.messageFrom(res, 'Gagal mengajukan cuti.'));
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
