import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_storage/get_storage.dart';

import '../providers/api_client.dart';
import '../providers/avana_api.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';

/// Persists clock actions per authenticated employee and keeps rejected entries
/// visible until the employee resolves them through attendance correction.
class AttendanceQueueService extends GetxService {
  static const _legacyKey = 'attendance_queue';
  static const _orphanedKey = 'attendance_queue_orphaned';

  final GetStorage _box = GetStorage();
  final AvanaApi _api = AvanaApi();

  final RxInt pendingCount = 0.obs;
  final RxInt failedCount = 0.obs;
  final RxnString lastFailure = RxnString();

  /// Changes after a successful or rejected sync so open screens can reload.
  final RxInt revision = 0.obs;

  bool _flushing = false;

  String? get _owner {
    if (!Get.isRegistered<AuthService>()) return null;
    final user = Get.find<AuthService>().user.value;
    if (user == null) return null;

    return '${user.tenantId ?? 'unknown'}:${user.id}:${user.employee?.id ?? 0}';
  }

  String _key(String owner) => 'attendance_queue_$owner';

  @override
  void onInit() {
    super.onInit();
    _quarantineLegacyQueue();
    _refreshCounts();

    final auth = Get.find<AuthService>();
    ever(auth.user, (_) {
      _refreshCounts();
      if (auth.user.value != null) flush();
    });

    final connectivity = Get.find<ConnectivityService>();
    ever<bool>(connectivity.online, (online) {
      if (online) flush();
    });
    if (connectivity.online.value) flush();
  }

  void _quarantineLegacyQueue() {
    final raw = _box.read<String>(_legacyKey);
    if (raw == null || raw.isEmpty) return;
    _box.write(_orphanedKey, raw);
    _box.remove(_legacyKey);
  }

  List<Map<String, dynamic>> _load(String owner) {
    final raw = _box.read<String>(_key(owner));
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _save(String owner, List<Map<String, dynamic>> queue) {
    _box.write(_key(owner), jsonEncode(queue));
    _refreshCounts();
  }

  void _refreshCounts() {
    final owner = _owner;
    final queue = owner == null ? const <Map<String, dynamic>>[] : _load(owner);
    pendingCount.value = queue
        .where((e) => e['sync_status'] != 'failed')
        .length;
    failedCount.value = queue.where((e) => e['sync_status'] == 'failed').length;
    final failures = queue.where((e) => e['sync_status'] == 'failed').toList();
    lastFailure.value = failures.isEmpty
        ? null
        : failures.last['failure_message']?.toString();
  }

  void enqueue(Map<String, dynamic> entry) {
    final owner = _owner;
    if (owner == null) return;
    final queue = _load(owner)
      ..add({...entry, 'owner': owner, 'sync_status': 'pending'});
    _save(owner, queue);
  }

  /// Remove rejected punches after a correction for the same work date exists.
  void resolveFailedForDate(String workDate) {
    final owner = _owner;
    if (owner == null) return;
    final queue = _load(owner);
    final remaining = queue.where((entry) {
      return entry['sync_status'] != 'failed' ||
          entry['work_date']?.toString() != workDate;
    }).toList();
    if (remaining.length == queue.length) return;

    _save(owner, remaining);
    revision.value++;
  }

  Future<void> flush() async {
    final owner = _owner;
    if (_flushing || owner == null) return;
    _flushing = true;
    var changed = false;
    try {
      final remaining = <Map<String, dynamic>>[];
      for (final entry in _load(owner)) {
        if (entry['owner'] != owner) {
          remaining.add({
            ...entry,
            'sync_status': 'failed',
            'failure_message': 'Pemilik antrean tidak cocok dengan sesi aktif.',
          });
          changed = true;
          continue;
        }
        if (entry['sync_status'] == 'failed') {
          remaining.add(entry);
          continue;
        }

        try {
          final nonce = entry['needs_nonce'] == true
              ? await _api.attendanceChallenge()
              : null;
          final res = await _api.clock(
            nonce: nonce,
            type: entry['type'] as String,
            workMode: entry['work_mode'] as String?,
            latitude: (entry['latitude'] as num?)?.toDouble(),
            longitude: (entry['longitude'] as num?)?.toDouble(),
            faceEmbedding: (entry['face_embedding'] as List?)
                ?.map((e) => (e as num).toDouble())
                .toList(),
            deviceId: entry['device_id'] as String?,
            isMockLocation: entry['is_mock_location'] as bool?,
            isRooted: entry['is_rooted'] as bool?,
            isEmulator: entry['is_emulator'] as bool?,
            clockedAt: entry['clocked_at'] as String?,
          );
          final code = res.statusCode ?? 0;
          if (code >= 200 && code < 300) {
            changed = true;
            continue;
          }
          if (code == 422) {
            remaining.add({
              ...entry,
              'sync_status': 'failed',
              'failure_message': ApiClient.messageFrom(
                res,
                'Absensi ditolak server. Ajukan koreksi absensi.',
              ),
            });
            changed = true;
            continue;
          }
          remaining.add(entry);
        } on DioException catch (error) {
          if (error.response?.statusCode == 422) {
            remaining.add({
              ...entry,
              'sync_status': 'failed',
              'failure_message': ApiClient.errorMessage(error),
            });
            changed = true;
          } else {
            remaining.add(entry);
          }
        }
      }
      _save(owner, remaining);
      if (changed) revision.value++;
    } finally {
      _flushing = false;
    }
  }
}
