import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../core/widgets/app_toast.dart';
import '../../data/models/mss.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

class MssMemberController extends GetxController {
  final AvanaApi _api = AvanaApi();

  /// The roster member tapped from the Tim tab (used for the header before the
  /// detail loads).
  final MssTeamMember member;

  MssMemberController(this.member);

  final isLoading = true.obs;
  final detail = Rxn<MssMemberDetail>();

  final shifts = <ShiftOption>[].obs;
  final assigning = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final results = await Future.wait([_api.mssMember(member.id), _api.mssShifts()]);
      detail.value = results[0] as MssMemberDetail;
      shifts.assignAll(results[1] as List<ShiftOption>);
    } catch (_) {
      // keep header from the passed member
    }
    isLoading.value = false;
  }

  /// Assign a shift (shiftId null = day off) to this member on [date]. Reloads
  /// the detail on success so the shown shift reflects the change.
  Future<bool> assignShift({required String date, int? shiftId}) async {
    assigning.value = true;
    try {
      final res = await _api.mssAssignShift(employeeId: member.id, date: date, shiftId: shiftId);
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        AppToast.success(ApiClient.messageFrom(res, 'Jadwal diperbarui'));
        await load();
        return true;
      }
      AppToast.error(ApiClient.messageFrom(res, 'Gagal mengatur shift.'));
      return false;
    } on DioException catch (e) {
      AppToast.error(ApiClient.messageFrom(e.response, 'Gagal terhubung ke server.'));
      return false;
    } finally {
      assigning.value = false;
    }
  }
}
