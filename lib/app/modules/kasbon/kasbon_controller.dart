import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../core/widgets/app_toast.dart';
import '../../data/models/ess_models.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

/// Backs the cash advance (uang muka) list. Detail rows are fetched on demand
/// and cached, so reopening one the employee already looked at is instant.
class KasbonController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final submitting = false.obs;
  final items = <CashAdvanceItem>[].obs;
  final statusFilter = 'all'.obs;

  final _details = <int, CashAdvanceDetail>{};

  /// Filter groups shown above the list, mapped to the API status values.
  static const filterGroups = <String, List<String>>{
    'pending': ['pending', 'approved'],
    'disbursed': ['disbursed', 'settled'],
    'rejected': ['rejected'],
  };

  List<CashAdvanceItem> get visibleItems {
    final group = filterGroups[statusFilter.value];

    return group == null
        ? items
        : items.where((e) => group.contains(e.status)).toList();
  }

  /// Money already handed over — the header figure.
  int get disbursedTotal => items
      .where((e) => e.status == 'disbursed' || e.status == 'settled')
      .fold(0, (sum, e) => sum + e.amount);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      items.assignAll(await _api.cashAdvances());
      _details.clear();
    } catch (_) {
      items.clear();
    }
    isLoading.value = false;
  }

  /// The full advance, from cache when it was already fetched.
  Future<CashAdvanceDetail> detail(int id, {bool refresh = false}) async {
    final cached = _details[id];
    if (cached != null && !refresh) {
      return cached;
    }

    final fetched = await _api.cashAdvance(id);
    _details[id] = fetched;

    return fetched;
  }

  Future<bool> submit({
    required int amount,
    required String purpose,
    required String neededDate,
    String? reason,
  }) async {
    submitting.value = true;
    try {
      final res = await _api.submitCashAdvance(
        amount: amount,
        purpose: purpose,
        neededDate: neededDate,
        reason: reason,
      );
      submitting.value = false;

      if (res.statusCode == 201) {
        AppToast.success('Pengajuan uang muka terkirim');
        await load();
        return true;
      }

      AppToast.error(ApiClient.messageFrom(res, 'Gagal mengajukan uang muka.'));
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
