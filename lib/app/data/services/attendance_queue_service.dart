import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_storage/get_storage.dart';

import '../providers/avana_api.dart';
import 'connectivity_service.dart';

/// Persists clock-in/out actions taken while offline and syncs them to the API
/// once connectivity returns, preserving each action's original time.
class AttendanceQueueService extends GetxService {
  static const _key = 'attendance_queue';

  final GetStorage _box = GetStorage();
  final AvanaApi _api = AvanaApi();

  /// Number of clock actions still waiting to sync.
  final RxInt pendingCount = 0.obs;

  bool _flushing = false;

  @override
  void onInit() {
    super.onInit();
    pendingCount.value = _load().length;

    final connectivity = Get.find<ConnectivityService>();
    ever<bool>(connectivity.online, (online) {
      if (online) flush();
    });
    if (connectivity.online.value) flush();
  }

  List<Map<String, dynamic>> _load() {
    final raw = _box.read<String>(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  void _save(List<Map<String, dynamic>> queue) {
    _box.write(_key, jsonEncode(queue));
    pendingCount.value = queue.length;
  }

  /// Queue a clock action for later delivery.
  void enqueue(Map<String, dynamic> entry) {
    final queue = _load()..add(entry);
    _save(queue);
  }

  /// Attempt to deliver every queued action. Server-rejected entries (HTTP 422 —
  /// already clocked, out of area, mock, etc.) are dropped; entries that fail on
  /// a network error are kept for the next attempt.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final remaining = <Map<String, dynamic>>[];
      for (final entry in _load()) {
        try {
          final res = await _api.clock(
            type: entry['type'] as String,
            latitude: (entry['latitude'] as num?)?.toDouble(),
            longitude: (entry['longitude'] as num?)?.toDouble(),
            deviceId: entry['device_id'] as String?,
            isMockLocation: entry['is_mock_location'] as bool?,
            isRooted: entry['is_rooted'] as bool?,
            clockedAt: entry['clocked_at'] as String?,
          );
          final code = res.statusCode ?? 0;
          if (code >= 200 && code < 300) continue; // synced → drop
          if (code == 422) continue; // rejected → drop (won't succeed on retry)
          remaining.add(entry); // 5xx / unexpected → retry later
        } on DioException {
          remaining.add(entry); // transport error → keep for next flush
        }
      }
      _save(remaining);
    } finally {
      _flushing = false;
    }
  }
}
