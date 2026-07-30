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
    search.value = value;
    isLoading.value = true;
    await load();
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
