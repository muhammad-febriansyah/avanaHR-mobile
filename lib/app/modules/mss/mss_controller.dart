import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../core/widgets/app_toast.dart';
import '../../data/models/mss.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

class MssController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final acting = false.obs;
  final approvals = <MssApproval>[].obs;
  final team = <MssTeamMember>[].obs;

  /// Composite keys currently selected for a bulk decision.
  final selected = <String>{}.obs;
  bool get selectionMode => selected.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final results = await Future.wait([_api.approvals(), _api.team()]);
      approvals.assignAll((results[0])
          .map((e) => MssApproval.fromJson(Map<String, dynamic>.from(e)))
          .toList());
      team.assignAll((results[1])
          .map((e) => MssTeamMember.fromJson(Map<String, dynamic>.from(e)))
          .toList());
    } catch (_) {
      // keep whatever loaded
    }
    isLoading.value = false;
  }

  void toggle(String id) {
    if (selected.contains(id)) {
      selected.remove(id);
    } else {
      selected.add(id);
    }
  }

  void clearSelection() => selected.clear();

  Future<void> act(String id, String action, {String? reason}) async {
    acting.value = true;
    try {
      final res = await _api.actApproval(id, action, reason: reason);
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        approvals.removeWhere((a) => a.id == id);
        selected.remove(id);
        AppToast.success(action == 'approve' ? 'Disetujui' : 'Ditolak');
      } else {
        AppToast.error(ApiClient.messageFrom(res, 'Gagal memproses.'));
      }
    } on DioException catch (e) {
      AppToast.error(ApiClient.messageFrom(e.response, 'Gagal terhubung ke server.'));
    } finally {
      acting.value = false;
    }
  }

  Future<void> bulk(String action, {String? reason}) async {
    if (selected.isEmpty) return;
    final ids = selected.toList();
    acting.value = true;
    try {
      final res = await _api.bulkApproval(ids, action, reason: reason);
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        approvals.removeWhere((a) => ids.contains(a.id));
        selected.clear();
        AppToast.success('${ids.length} permintaan ${action == 'approve' ? 'disetujui' : 'ditolak'}');
      } else {
        AppToast.error(ApiClient.messageFrom(res, 'Gagal memproses.'));
      }
    } on DioException catch (e) {
      AppToast.error(ApiClient.messageFrom(e.response, 'Gagal terhubung ke server.'));
    } finally {
      acting.value = false;
    }
  }
}
