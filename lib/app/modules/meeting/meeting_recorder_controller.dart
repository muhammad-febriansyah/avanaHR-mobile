import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/widgets/app_toast.dart';
import '../../data/models/meeting.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

/// Drives one live recording.
///
/// Audio goes straight from the microphone to the speech provider over a
/// WebSocket — it never passes through AvanaHR — which is what lets the
/// transcript appear as people speak. The socket is opened with a token that
/// expires within the minute, minted by our own server, so the provider's
/// project key is never on the phone.
///
/// What does come back to AvanaHR is the finished text, posted in batches every
/// [_heartbeat]. That batch is the only copy the server will ever hold, and it
/// doubles as the meter: the server bills the audio it covers. So a dropped
/// batch loses transcript AND under-bills, which is why unsent segments are
/// kept and retried rather than discarded, and why re-sending is safe (the
/// server keys them on their offset).
class MeetingRecorderController extends GetxController {
  MeetingRecorderController({required this.meeting, required this.status});

  /// The meeting row the server opened before the microphone was touched.
  final MeetingItem meeting;

  final MeetingRecorderStatus status;

  final AvanaApi _api = AvanaApi();
  final AudioRecorder _recorder = AudioRecorder();

  /// How often finished text is handed to the server.
  static const _heartbeat = Duration(seconds: 10);

  /// PCM the provider is configured for (mirrors the grant's params).
  static const _sampleRate = 16000;

  final elapsed = Duration.zero.obs;
  final isPaused = false.obs;
  final isStopping = false.obs;

  /// Transcript settled so far, newest last — what the screen scrolls through.
  final lines = <String>[].obs;

  /// The words currently being revised as the speaker talks.
  final interim = ''.obs;

  /// Rolling microphone levels, for the waveform.
  final levels = <double>[].obs;

  /// Set when the server tells us to stop (wallet empty, ceiling reached).
  final stoppedReason = RxnString();

  WebSocketChannel? _socket;
  StreamSubscription? _socketSub;
  StreamSubscription<List<int>>? _micSub;
  Timer? _ticker;
  Timer? _pusher;
  DateTime? _startedAt;

  /// Audio already accounted for when the recording was paused.
  Duration _accumulated = Duration.zero;

  /// Finished utterances not yet acknowledged by the server.
  final List<PendingSegment> _pending = [];

  /// Offsets already handed over, so a retry does not queue duplicates.
  final Set<int> _sentOffsets = {};

  bool _closing = false;

  @override
  void onInit() {
    super.onInit();
    _begin();
  }

  @override
  void onClose() {
    _teardown();
    _recorder.dispose();
    super.onClose();
  }

  /// Get the recording going, or close the meeting the server already opened.
  ///
  /// Every failure here has to end in [_abandon]: the row exists before the
  /// microphone is touched, so any path that just walks away leaves a meeting
  /// stuck at "Merekam" with nothing able to move it on.
  Future<void> _begin() async {
    if (!await _recorder.hasPermission()) {
      await _abandon('Izin mikrofon ditolak. Aktifkan di pengaturan HP.');
      return;
    }

    try {
      await _openSocket();
    } on DioException catch (e) {
      await _abandon(ApiClient.errorMessage(e));
      return;
    } catch (e) {
      // Anything that is not the server refusing: the socket itself would not
      // open. Carry the reason through rather than replacing it with a generic
      // line — this is the message somebody debugging a recorder that will not
      // start has to work from.
      await _abandon('Gagal memulai sesi transkripsi. $e');
      return;
    }

    try {
      await _startMic();
    } catch (e) {
      // The socket is up but the microphone would not open — another app holds
      // it, or the permission was revoked between the check and the call.
      await _abandon('Mikrofon tidak bisa dibuka. $e');
      return;
    }

    _startedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _pusher = Timer.periodic(_heartbeat, (_) => _push());
  }

  /// Open the listening socket with a freshly minted grant.
  Future<void> _openSocket() async {
    final grant = await _api.meetingSttGrant(meeting.id);

    final channel = WebSocketChannel.connect(
      grant.uri,
      protocols: ['token', grant.accessToken],
    );

    await channel.ready;

    _socket = channel;
    _socketSub = channel.stream.listen(
      _onProviderMessage,
      onError: (_) => _reconnect(),
      onDone: () {
        // A socket that closes while we still mean to be recording is a
        // dropped connection, not a stop — the provider caps session length
        // and networks wobble. Reopen and keep the clock running.
        if (!_closing && !isPaused.value) _reconnect();
      },
      cancelOnError: true,
    );
  }

  Future<void> _startMic() async {
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );

    _micSub = stream.listen((chunk) {
      if (isPaused.value || _closing) return;

      _socket?.sink.add(chunk);
      _pushLevel(chunk);
    });
  }

  /// Rough loudness of a PCM16 chunk, for the waveform bars.
  void _pushLevel(List<int> chunk) {
    if (chunk.length < 2) return;

    var peak = 0;
    // Every 64th frame is plenty to size a bar, and keeps this off the
    // critical path of a stream that fires many times a second.
    for (var i = 0; i + 1 < chunk.length; i += 128) {
      var sample = chunk[i] | (chunk[i + 1] << 8);
      if (sample > 32767) sample -= 65536;
      final magnitude = sample.abs();
      if (magnitude > peak) peak = magnitude;
    }

    final level = (peak / 32768).clamp(0.02, 1.0).toDouble();
    levels.add(level);
    if (levels.length > 48) levels.removeAt(0);
  }

  /// A message from the speech provider: interim words, or a settled utterance.
  void _onProviderMessage(dynamic raw) {
    if (raw is! String) return;

    late final Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return;
    }

    final alternatives =
        (data['channel'] as Map?)?['alternatives'] as List? ?? const [];
    if (alternatives.isEmpty) return;

    final alternative = Map<String, dynamic>.from(alternatives.first as Map);
    final text = (alternative['transcript'] ?? '').toString().trim();
    if (text.isEmpty) return;

    if (data['is_final'] != true) {
      interim.value = text;
      return;
    }

    interim.value = '';

    final startMs = (((data['start'] as num?) ?? 0) * 1000).round();
    final durationMs = (((data['duration'] as num?) ?? 0) * 1000).round();

    // Diarization tags each word; the utterance takes the speaker of its first.
    final words = (alternative['words'] as List?) ?? const [];
    final speaker = words.isEmpty
        ? 0
        : ((words.first as Map)['speaker'] as num?)?.toInt() ?? 0;

    if (_sentOffsets.add(startMs)) {
      _pending.add(
        PendingSegment(
          startMs: startMs,
          endMs: startMs + durationMs,
          speaker: speaker,
          text: text,
        ),
      );
    }

    lines.add(text);
    if (lines.length > 200) lines.removeAt(0);
  }

  void _tick() {
    if (isPaused.value || _closing) return;

    elapsed.value =
        _accumulated +
        (_startedAt == null
            ? Duration.zero
            : DateTime.now().difference(_startedAt!));
  }

  /// Hand the settled text and the clock to the server.
  Future<void> _push({bool force = false}) async {
    if (_closing && !force) return;
    if (_pending.isEmpty && !force) return;

    final batch = List<PendingSegment>.from(_pending);

    try {
      final result = await _api.pushMeetingSegments(
        id: meeting.id,
        segments: batch,
        elapsedMs: elapsed.value.inMilliseconds,
      );

      // Only clear what the server took. Anything that arrived mid-flight
      // stays queued for the next beat.
      _pending.removeRange(0, batch.length);

      if (result['stop'] == true) {
        await _forceStop(result['message']?.toString());
      }
    } on DioException catch (e) {
      // 409 is the server refusing to let the recording continue — the wallet
      // is empty or the ceiling is reached. Anything else is a transient
      // network problem: keep the batch and try again on the next beat.
      if (e.response?.statusCode == 409) {
        String? message;
        final body = e.response?.data;

        if (body is Map) {
          final data = body['data'];
          if (data is Map) {
            message = data['message']?.toString();
          }
        }

        await _forceStop(message ?? 'Rekaman dihentikan oleh sistem.');
      }
    }
  }

  /// The provider dropped us. Reopen with a new grant, keeping the clock.
  Future<void> _reconnect() async {
    if (_closing || isPaused.value) return;

    await _socketSub?.cancel();
    _socketSub = null;
    await _socket?.sink.close();
    _socket = null;

    try {
      await _openSocket();
    } catch (_) {
      // Leave it; the next microphone chunk finds no socket and the following
      // heartbeat still delivers whatever text we already hold.
    }
  }

  Future<void> togglePause() async {
    if (_closing) return;

    if (isPaused.value) {
      _startedAt = DateTime.now();
      isPaused.value = false;
      await _openSocket();
      return;
    }

    _accumulated = elapsed.value;
    isPaused.value = true;
    interim.value = '';

    await _socketSub?.cancel();
    _socketSub = null;
    await _socket?.sink.close();
    _socket = null;

    // The pause is a good moment to settle up: everything heard so far is
    // safely on the server before anyone walks away.
    await _push(force: true);
  }

  /// Finish the recording and hand it over for summarising.
  Future<void> stop() async {
    if (_closing) return;

    isStopping.value = true;
    _closing = true;

    await _teardown();
    await _push(force: true);

    try {
      await _api.stopMeeting(
        id: meeting.id,
        elapsedMs: elapsed.value.inMilliseconds,
      );
    } on DioException catch (e) {
      AppToast.error(ApiClient.errorMessage(e));
    }

    isStopping.value = false;

    Get.back(result: true);
    AppToast.success(
      'Rekaman selesai. Ringkasan sedang dibuat — Anda akan diberi tahu.',
    );
  }

  /// The server said to stop mid-recording. Same path as a manual stop, but
  /// the person is told why.
  Future<void> _forceStop(String? message) async {
    if (_closing) return;

    stoppedReason.value = message;
    await stop();

    if (message != null && message.isNotEmpty) {
      AppToast.warning(message);
    }
  }

  /// Close a recording that never got going, and say why.
  ///
  /// The server opened the meeting before the microphone was touched, so
  /// walking away without telling it leaves a row stuck at "Merekam" for good.
  /// Stopping it lets the normal path finish: with no speech captured it is
  /// marked failed, which is what actually happened.
  Future<void> _abandon(String message) async {
    _closing = true;
    await _teardown();

    try {
      await _api.stopMeeting(id: meeting.id, elapsedMs: 0);
    } on DioException {
      // The recording is already lost; a failed tidy-up is not worth a second
      // error on top of the one being shown.
    }

    Get.back(result: false);
    AppToast.error(message);
  }

  /// Give up on a recording started by mistake.
  ///
  /// Still stopped server-side rather than simply left: anything already
  /// transcribed has been billed and stored, and a row left in "Merekam"
  /// never leaves that state on its own.
  Future<void> discard() async {
    _closing = true;
    await _teardown();

    try {
      await _api.stopMeeting(
        id: meeting.id,
        elapsedMs: elapsed.value.inMilliseconds,
      );
    } on DioException {
      // Nothing useful to do here; the recording is over either way.
    }

    Get.back(result: false);
  }

  Future<void> _teardown() async {
    _ticker?.cancel();
    _pusher?.cancel();
    _ticker = null;
    _pusher = null;

    await _micSub?.cancel();
    _micSub = null;

    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }

    await _socketSub?.cancel();
    _socketSub = null;
    await _socket?.sink.close();
    _socket = null;
  }

  /// `HH:MM:SS`, the way a stopwatch reads.
  String get clock {
    final d = elapsed.value;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// How close the recording is to the server's hard ceiling.
  double get ceilingFraction {
    final max = status.maxMinutes ?? 180;
    return (elapsed.value.inSeconds / (max * 60)).clamp(0.0, 1.0);
  }
}
