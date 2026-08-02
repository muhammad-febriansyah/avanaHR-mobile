import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../core/widgets/app_toast.dart';
import '../../data/models/meeting.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';
import 'meeting_recorder_view.dart';

/// The AI Recorder landing screen: what has been recorded, and the way to
/// start a new one.
class MeetingController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final isStarting = false.obs;
  final meetings = <MeetingItem>[].obs;
  final status = MeetingRecorderStatus.unavailable.obs;

  final search = ''.obs;

  /// Which tab is showing: 0 starts a recording, 1 reads the old ones.
  ///
  /// Split rather than stacked because the two have nothing to say to each
  /// other: somebody about to record wants one button, somebody looking for
  /// last Tuesday's meeting wants the whole screen to be a list.
  final tab = 0.obs;

  /// The status the archive is narrowed to, or null for everything.
  final statusFilter = RxnString();

  /// A search round-trip, which must not blank the tabs the way [isLoading] does.
  final isFiltering = false.obs;

  /// Archive filters, in the order they are offered.
  static const filters = <({String label, String? key})>[
    (label: 'Semua', key: null),
    (label: 'Siap', key: 'ready'),
    (label: 'Diproses', key: 'processing'),
    (label: 'Gagal', key: 'failed'),
  ];

  /// Recording and processing are one thing to somebody scanning a list: the
  /// meeting is not readable yet.
  bool matches(MeetingItem meeting, String? key) => switch (key) {
    null => true,
    'processing' => meeting.isWorking,
    _ => meeting.status == key,
  };

  /// What the archive shows, once the status filter has had its say. Search is
  /// left to the server so a title that has scrolled off the page is still
  /// findable.
  List<MeetingItem> get visible =>
      meetings.where((meeting) => matches(meeting, statusFilter.value)).toList();

  int countOf(String? key) =>
      meetings.where((meeting) => matches(meeting, key)).length;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      // Asked together so the record button's state and the list never
      // disagree on screen.
      final results = await Future.wait([
        _api.meetingStatus(),
        _api.meetings(search: search.value),
      ]);

      status.value = results[0] as MeetingRecorderStatus;
      meetings.value = results[1] as List<MeetingItem>;
    } on DioException catch (e) {
      AppToast.error(ApiClient.errorMessage(e));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> applySearch(String value) async {
    final term = value.trim();
    if (term == search.value) return;

    search.value = term;
    isFiltering.value = true;

    try {
      await load();
    } finally {
      isFiltering.value = false;
    }
  }

  /// Open a recording on the server, then hand over to the recorder screen.
  ///
  /// The server is asked first on purpose: it refuses when the wallet cannot
  /// fund the session, and being told that before the microphone opens is far
  /// better than forty minutes in.
  Future<void> start({required String title, String? location}) async {
    if (isStarting.value) return;

    isStarting.value = true;

    try {
      final meeting = await _api.startMeeting(title: title, location: location);

      await Get.to<bool>(
        () => MeetingRecorderView(meeting: meeting, status: status.value),
        fullscreenDialog: true,
      );

      await load();
    } on DioException catch (e) {
      AppToast.error(ApiClient.errorMessage(e));
    } finally {
      isStarting.value = false;
    }
  }
}
