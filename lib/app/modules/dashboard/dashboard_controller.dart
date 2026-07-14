import 'package:get/get.dart';

import '../../data/models/mss.dart';
import '../../data/providers/avana_api.dart';

/// Manager dashboard: team-scoped KPIs (today's attendance, pending approvals,
/// month recap) sourced from the MSS endpoints. Not company-wide admin numbers.
class DashboardController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final teamCount = 0.obs;
  final pendingCount = 0.obs;

  /// Today's team attendance summary and the current month's recap.
  final Rxn<TeamRecapSummary> today = Rxn<TeamRecapSummary>();
  final Rxn<TeamRecapSummary> month = Rxn<TeamRecapSummary>();

  /// A short preview of the pending approvals for the header list.
  final pendingPreview = <MssApproval>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  String _todayStr() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> load() async {
    isLoading.value = true;
    final t = _todayStr();
    try {
      final team = await _api.team();
      teamCount.value = team.length;

      final apps = (await _api.approvals())
          .map((e) => MssApproval.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      pendingCount.value = apps.length;
      pendingPreview.assignAll(apps.take(3));

      today.value = (await _api.mssTeamRecap(start: t, end: t)).summary;
      month.value = (await _api.mssTeamRecap()).summary;
    } catch (_) {
      // Keep whatever loaded; the view shows zeros / empty states.
    }
    isLoading.value = false;
  }
}
