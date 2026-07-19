import 'package:get/get.dart';

import '../../data/models/ess_models.dart';
import '../../data/providers/avana_api.dart';

/// Backs the settlement list. Detail rows are fetched on demand and cached, so
/// reopening a settlement the employee already looked at is instant.
class SettlementController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final items = <SettlementItem>[].obs;
  final statusFilter = 'all'.obs;

  final _details = <int, SettlementDetail>{};

  /// Filter groups shown above the list, mapped to the API status values.
  static const filterGroups = <String, List<String>>{
    'pending': ['draft', 'submitted', 'manager_approved'],
    'paid': ['paid'],
    'rejected': ['rejected'],
  };

  List<SettlementItem> get visibleItems {
    final group = filterGroups[statusFilter.value];

    return group == null
        ? items
        : items.where((e) => group.contains(e.status)).toList();
  }

  /// Total of everything already disbursed — the list header figure.
  int get paidTotal => items
      .where((e) => e.status == 'paid')
      .fold(0, (sum, e) => sum + e.total);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      items.assignAll(await _api.settlements());
      _details.clear();
    } catch (_) {
      items.clear();
    }
    isLoading.value = false;
  }

  /// The full settlement, from cache when it was already fetched.
  Future<SettlementDetail> detail(int id, {bool refresh = false}) async {
    final cached = _details[id];
    if (cached != null && !refresh) {
      return cached;
    }

    final fetched = await _api.settlement(id);
    _details[id] = fetched;

    return fetched;
  }
}
