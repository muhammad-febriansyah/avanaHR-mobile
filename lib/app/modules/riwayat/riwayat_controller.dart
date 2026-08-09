import 'package:get/get.dart';

import '../../data/models/activity.dart';
import '../../data/providers/avana_api.dart';
import '../../data/services/attendance_queue_service.dart';

/// Backs the "Riwayat" tab: a merged activity feed from `/me/activities`.
class RiwayatController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final loadFailed = false.obs;
  final items = <ActivityItem>[].obs;
  final typeFilter = 'all'.obs;

  /// Inclusive date range filter (day precision); null = no date filter.
  final dateFrom = Rxn<DateTime>();
  final dateTo = Rxn<DateTime>();
  late final Worker _queueWorker;

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
    load();
  }

  void clearDateRange() {
    dateFrom.value = null;
    dateTo.value = null;
    load();
  }

  @override
  void onInit() {
    super.onInit();
    _queueWorker = ever<int>(
      Get.find<AttendanceQueueService>().revision,
      (_) => load(),
    );
    load();
  }

  @override
  void onClose() {
    _queueWorker.dispose();
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;
    loadFailed.value = false;
    try {
      items.value = await _api.activities(
        from: dateFrom.value,
        to: dateTo.value,
      );
    } catch (_) {
      loadFailed.value = true;
    }
    isLoading.value = false;
  }
}
