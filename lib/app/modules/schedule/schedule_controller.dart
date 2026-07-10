import 'package:get/get.dart';

import '../../data/models/schedule.dart';
import '../../data/providers/avana_api.dart';

class ScheduleController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final days = <ShiftDay>[].obs;

  /// Monday of the currently viewed week (null = current week).
  final weekStart = Rxn<DateTime>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final start = weekStart.value;
      days.assignAll(await _api.schedule(
        start: start != null ? _fmt(start) : null,
      ));
    } catch (_) {
      days.clear();
    }
    isLoading.value = false;
  }

  void shiftWeek(int deltaWeeks) {
    final base = weekStart.value ?? _mondayOf(DateTime.now());
    weekStart.value = base.add(Duration(days: 7 * deltaWeeks));
    load();
  }

  void resetToThisWeek() {
    weekStart.value = null;
    load();
  }

  DateTime _mondayOf(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
