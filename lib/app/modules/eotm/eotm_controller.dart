import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../core/widgets/app_toast.dart';
import '../../data/models/ess_models.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

/// Employee of the Month voting: the open period, the ballot, and the live
/// tally. One vote per employee per period — voting again replaces it, which is
/// why the screen shows the current choice rather than hiding the form.
class EotmController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final submitting = false.obs;

  final period = Rxn<EotmPeriodItem>();
  final myVote = Rxn<EotmMyVote>();
  final coreValues = <EotmCoreValueItem>[].obs;
  final standings = <EotmStandingItem>[].obs;

  final nominees = <EotmNomineeItem>[].obs;
  final loadingNominees = false.obs;

  /// Ballot state, kept here so the sheet survives a rebuild.
  final selectedNominee = Rxn<EotmNomineeItem>();
  final selectedValueId = Rxn<int>();

  Timer? _searchDebounce;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  bool get canVote => period.value?.isOpen == true;

  Future<void> load() async {
    isLoading.value = true;

    try {
      final snapshot = await _api.eotm();
      period.value = snapshot.period;
      myVote.value = snapshot.myVote;
      coreValues.assignAll(snapshot.coreValues);
      standings.assignAll(snapshot.standings);
      selectedValueId.value = snapshot.myVote?.coreValueId;
    } catch (_) {
      period.value = null;
      standings.clear();
    }

    isLoading.value = false;
  }

  /// Debounced so typing a name doesn't fire a request per keystroke.
  void searchNominees(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => loadNominees(query),
    );
  }

  Future<void> loadNominees([String? query]) async {
    loadingNominees.value = true;

    try {
      nominees.assignAll(await _api.eotmNominees(search: query));
    } catch (_) {
      nominees.clear();
    }

    loadingNominees.value = false;
  }

  Future<bool> submitVote({String? reason}) async {
    final nominee = selectedNominee.value;

    if (nominee == null) {
      AppToast.warning('Pilih dulu karyawan yang kamu vote.');
      return false;
    }

    submitting.value = true;

    try {
      await _api.eotmVote(
        nomineeId: nominee.id,
        coreValueId: selectedValueId.value,
        reason: reason,
      );
      submitting.value = false;

      AppToast.success('Vote kamu tersimpan');
      await load();
      return true;
    } on DioException catch (e) {
      submitting.value = false;
      AppToast.error(ApiClient.errorMessage(e));
      return false;
    }
  }
}
