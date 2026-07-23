import 'package:dio/dio.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart' hide Response;

import '../../core/widgets/app_toast.dart';
import '../../data/models/ess_models.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

/// One row of the checklist being drafted, with the evidence attached to it.
class VisitTaskDraft {
  String title;
  String? beforePath;
  String? afterPath;
  String note;

  VisitTaskDraft(this.title, {this.beforePath, this.afterPath, this.note = ''});
}

class VisitingController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final submitting = false.obs;
  final items = <FieldVisitItem>[].obs;

  /// Server-side search over location / client / purpose. Debounced in
  /// [onInit] so typing does not fire a request per keystroke.
  final query = ''.obs;

  // ---- Pagination (infinite scroll) ----
  static const _perPage = 20;
  final _page = 1.obs;
  final _lastPage = 1.obs;
  final loadingMore = false.obs;

  bool get hasMore => _page.value < _lastPage.value;

  // ---- Precise location, held while the report form is open ----

  final position = Rxn<Position>();
  final address = ''.obs;
  final locating = false.obs;

  /// Draft checklist for the report being written. Each entry is a task title;
  /// `done` is not sent — a task is ticked off later, from the visit list.
  final tasks = <VisitTaskDraft>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
    // Re-run the (server-side) search a beat after the user stops typing.
    debounce(
      query,
      (_) => load(),
      time: const Duration(milliseconds: 350),
    );
  }

  /// (Re)load the first page for the current [query]. Used by initial load,
  /// pull-to-refresh, and the search debounce.
  Future<void> load() async {
    isLoading.value = true;
    try {
      final res = await _api.fieldVisits(
        page: 1,
        search: query.value,
        perPage: _perPage,
      );
      items.assignAll(res.items);
      _page.value = res.currentPage;
      _lastPage.value = res.lastPage;
    } catch (_) {}
    isLoading.value = false;
  }

  /// Fetch the next page and append it. No-op while a page is already in
  /// flight or once the last page has been reached.
  Future<void> loadMore() async {
    if (loadingMore.value || !hasMore) {
      return;
    }

    loadingMore.value = true;
    try {
      final res = await _api.fieldVisits(
        page: _page.value + 1,
        search: query.value,
        perPage: _perPage,
      );
      items.addAll(res.items);
      _page.value = res.currentPage;
      _lastPage.value = res.lastPage;
    } catch (_) {}
    loadingMore.value = false;
  }

  /// Clear the draft so a second report does not inherit the first one's
  /// checklist or a stale GPS fix.
  void resetDraft() {
    tasks.clear();
    position.value = null;
    address.value = '';
  }

  void addTask(String title) {
    final trimmed = title.trim();

    if (trimmed.isEmpty || tasks.any((t) => t.title == trimmed)) {
      return;
    }

    tasks.add(VisitTaskDraft(trimmed));
  }

  void removeTask(int index) => tasks.removeAt(index);

  /// Attach or clear a task's evidence. Rx lists do not notice a mutated
  /// element, so the refresh is what redraws the row.
  void setTaskPhoto(int index, {String? before, String? after}) {
    if (before != null) tasks[index].beforePath = before;
    if (after != null) tasks[index].afterPath = after;
    tasks.refresh();
  }

  void clearTaskPhoto(int index, {bool before = false, bool after = false}) {
    if (before) tasks[index].beforePath = null;
    if (after) tasks[index].afterPath = null;
    tasks.refresh();
  }

  void setTaskNote(int index, String note) {
    tasks[index].note = note;
  }

  /// Take a GPS fix and turn it into a full street address for the report.
  /// Both halves are best-effort: a fix without an address is still useful.
  Future<void> refreshLocation() async {
    locating.value = true;

    final pos = await currentPosition();
    position.value = pos;

    if (pos == null) {
      locating.value = false;
      AppToast.warning('Lokasi tidak tersedia. Aktifkan GPS & izinkan akses.');

      return;
    }

    address.value = await _describe(pos) ?? '';
    locating.value = false;
  }

  /// Full street address for a fix, or null when geocoding gives nothing.
  Future<String?> _describe(Position pos) async {
    try {
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);

      if (marks.isEmpty) {
        return null;
      }

      final p = marks.first;
      final parts = <String?>[
        p.street,
        p.subLocality,
        p.locality,
        p.subAdministrativeArea,
      ].where((e) => e != null && e.trim().isNotEmpty).cast<String>().toList();

      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  /// Best-effort current GPS; null if permission denied or service off.
  Future<Position?> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  Future<bool> submit({
    required String visitDate,
    required String location,
    String? clientName,
    String? purpose,
    String? notes,
    double? latitude,
    double? longitude,
    List<String> photoPaths = const [],
    List<VisitTaskDraft> taskDrafts = const [],
  }) async {
    submitting.value = true;
    try {
      final res = await _api.submitFieldVisit(
        visitDate: visitDate,
        location: location,
        clientName: clientName,
        purpose: purpose,
        notes: notes,
        latitude: latitude,
        longitude: longitude,
        photoPaths: photoPaths,
        tasks: taskDrafts.map((t) => t.title).toList(),
        taskNotes: taskDrafts.map((t) => t.note).toList(),
        taskBeforePaths: taskDrafts.map((t) => t.beforePath).toList(),
        taskAfterPaths: taskDrafts.map((t) => t.afterPath).toList(),
      );
      submitting.value = false;

      if (res.statusCode == 201) {
        await load();
        return true;
      }

      AppToast.error(ApiClient.messageFrom(res, 'Gagal menyimpan kunjungan.'));
      return false;
    } on DioException catch (e) {
      submitting.value = false;
      AppToast.error(ApiClient.errorMessage(e));
      return false;
    }
  }
}
