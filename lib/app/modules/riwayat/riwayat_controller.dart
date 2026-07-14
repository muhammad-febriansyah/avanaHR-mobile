import 'package:get/get.dart';

import '../../data/models/activity.dart';
import '../../data/providers/avana_api.dart';

/// Backs the "Riwayat" tab: a merged activity feed from `/me/activities`.
class RiwayatController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final items = <ActivityItem>[].obs;
  final typeFilter = 'all'.obs;

  /// Inclusive date range filter (day precision); null = no date filter.
  final dateFrom = Rxn<DateTime>();
  final dateTo = Rxn<DateTime>();

  bool get hasDateFilter => dateFrom.value != null && dateTo.value != null;

  /// Activities narrowed to the selected type ('all' = everything) and, when
  /// set, the selected date range.
  List<ActivityItem> get visibleItems {
    var list = typeFilter.value == 'all'
        ? items.toList()
        : items.where((e) => e.type == typeFilter.value).toList();

    final from = dateFrom.value;
    final to = dateTo.value;
    if (from != null && to != null) {
      list = list.where((e) {
        final d = e.occurredAt;
        if (d == null) return false;
        final day = DateTime(d.year, d.month, d.day);
        return !day.isBefore(from) && !day.isAfter(to);
      }).toList();
    }
    return list;
  }

  void setDateRange(DateTime from, DateTime to) {
    dateFrom.value = DateTime(from.year, from.month, from.day);
    dateTo.value = DateTime(to.year, to.month, to.day);
  }

  void clearDateRange() {
    dateFrom.value = null;
    dateTo.value = null;
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      items.value = await _api.activities();
    } catch (_) {
      items.clear();
    }
    isLoading.value = false;
  }
}
