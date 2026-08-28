import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_storage/get_storage.dart';

import '../models/tracking.dart';
import '../providers/avana_api.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'tracking_queue_repository.dart';

/// Orchestrates the visible, work-session-only location stream.
///
/// GPS is produced by Geolocator's native stream, not a Dart polling timer.
/// Android runs it as a foreground service with an ongoing notification; iOS
/// uses the location background mode and shows the system location indicator.
class TrackingService extends GetxService {
  static const _batchSize = 5;
  static const _flushInterval = Duration(seconds: 45);
  static const _locationInterval = Duration(seconds: 25);

  final AvanaApi _api = AvanaApi();
  final GetStorage _box = GetStorage();
  final TrackingQueueRepository _queue = TrackingQueueRepository();

  final Rxn<TrackingSessionState> session = Rxn<TrackingSessionState>();
  final RxBool isTracking = false.obs;
  final RxBool isSyncing = false.obs;
  final RxInt pendingPoints = 0.obs;
  final RxnString warning = RxnString();
  final Rxn<DateTime> lastRecordedAt = Rxn<DateTime>();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _flushTimer;
  late final Worker _authWorker;
  late final Worker _connectivityWorker;
  bool _starting = false;

  String? get _owner {
    if (!Get.isRegistered<AuthService>()) return null;
    final user = Get.find<AuthService>().user.value;
    if (user?.employee == null) return null;

    return '${user!.tenantId ?? 'unknown'}:${user.id}:${user.employee!.id}';
  }

  String _sessionKey(String owner) => 'tracking_session_$owner';

  @override
  void onInit() {
    super.onInit();
    final auth = Get.find<AuthService>();
    final connectivity = Get.find<ConnectivityService>();

    _authWorker = ever(auth.user, (_) {
      if (auth.user.value == null) {
        unawaited(stop(clearSession: false));
      } else {
        unawaited(restore());
      }
    });
    _connectivityWorker = ever<bool>(connectivity.online, (online) {
      if (online) unawaited(restoreAndFlush());
    });

    if (auth.user.value != null) unawaited(restore());
  }

  /// Rehydrate an active server session after app restart or login.
  Future<void> restore() async {
    final owner = _owner;
    if (owner == null) return;

    TrackingSessionState? active;
    if (Get.find<ConnectivityService>().online.value) {
      try {
        active = await _api.activeTrackingSession();
      } catch (_) {
        active = _readCachedSession(owner);
      }
    } else {
      active = _readCachedSession(owner);
    }

    pendingPoints.value = _queue.read(owner).length;
    if (active?.isActive == true) {
      await start(active!);
    } else if (active == null && session.value != null) {
      await stop();
    }
  }

  Future<void> restoreAndFlush() async {
    if (session.value == null) await restore();
    await flush();
  }

  /// Attach the session returned by Clock In and start native GPS collection.
  Future<void> start(TrackingSessionState active) async {
    if (_starting) return;
    _starting = true;
    try {
      session.value = active;
      _cacheSession(active);
      await _startPositionStream();
      await flush();
    } finally {
      _starting = false;
    }
  }

  /// Start collecting while an offline Clock In waits in the attendance queue.
  /// Points stay unbound locally until that punch creates its server session.
  Future<void> startPendingClockIn() async {
    warning.value = null;
    await _startPositionStream();
  }

  Future<void> _startPositionStream() async {
    if (_positionSubscription != null) {
      isTracking.value = true;
      return;
    }

    warning.value = null;
    if (!await Geolocator.isLocationServiceEnabled()) {
      warning.value = 'GPS mati. Tracking lokasi belum dapat dimulai.';
      isTracking.value = false;
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      warning.value = permission == LocationPermission.deniedForever
          ? 'Izin lokasi ditolak permanen. Aktifkan dari Pengaturan.'
          : 'Izin lokasi ditolak. Tracking tidak aktif.';
      isTracking.value = false;
      return;
    }

    // iOS background location needs Always permission. Attendance remains valid
    // when it is declined, but the app says tracking is disabled rather than
    // pretending a foreground-only stream is background-safe.
    if (Platform.isIOS && permission != LocationPermission.always) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always) {
        warning.value =
            'Pilih izin lokasi “Selalu” agar tracking tetap aktif saat layar terkunci.';
        isTracking.value = false;
        return;
      }
    }

    final settings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
            intervalDuration: _locationInterval,
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'AvanaHR',
              notificationText: 'Tracking lokasi aktif selama jam kerja.',
              notificationChannelName: 'Tracking jam kerja',
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
            activityType: ActivityType.fitness,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
            allowBackgroundLocationUpdates: true,
          );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
          _record,
          onError: (Object error) {
            warning.value =
                'Tracking GPS terganggu. Buka aplikasi untuk mencoba ulang.';
            debugPrint('[Tracking] position stream error: $error');
          },
          cancelOnError: false,
        );
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) => unawaited(flush()));
    isTracking.value = true;
  }

  void _record(Position position) {
    final owner = _owner;
    if (owner == null) return;

    final point = TrackingPoint(
      clientUuid: _uuidV4(),
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed >= 0 ? position.speed : null,
      heading: position.heading >= 0 ? position.heading : null,
      isMocked: position.isMocked,
      recordedAt: position.timestamp.toUtc().toIso8601String(),
    );
    _queue.append(owner, point);
    pendingPoints.value = _queue.read(owner).length;
    lastRecordedAt.value = position.timestamp;

    if (pendingPoints.value >= _batchSize) unawaited(flush());
  }

  /// Upload at most ten points per request. UUIDs make retries idempotent.
  Future<void> flush() async {
    final owner = _owner;
    final active = session.value;
    if (owner == null ||
        active == null ||
        isSyncing.value ||
        !Get.find<ConnectivityService>().online.value) {
      return;
    }

    isSyncing.value = true;
    try {
      while (true) {
        final batch = _queue.read(owner).take(10).toList();
        if (batch.isEmpty) break;

        final response = await _api.uploadTrackingLocations(
          sessionId: active.id,
          locations: batch,
        );
        final code = response.statusCode ?? 0;
        if (code >= 200 && code < 300) {
          _queue.remove(owner, batch.map((point) => point.clientUuid));
          pendingPoints.value = _queue.read(owner).length;
          continue;
        }
        if (code == 404 || code == 422) {
          warning.value =
              'Sesi tracking sudah berakhir. Lokasi tidak dikirim lagi.';
          await stop();
        }
        break;
      }
    } on DioException catch (error) {
      final code = error.response?.statusCode;
      if (code == 404 || code == 422) {
        warning.value =
            'Sesi tracking sudah berakhir. Lokasi tidak dikirim lagi.';
        await stop();
      }
      // Other errors are transport/server failures. Keep every point locally.
    } catch (error) {
      debugPrint('[Tracking] sync failed: $error');
    } finally {
      isSyncing.value = false;
    }
  }

  /// Called immediately before an online Clock Out.
  Future<void> prepareClockOut() => flush();

  /// Offline Clock Out stops GPS immediately but preserves session + points so
  /// the attendance queue can flush them before replaying the punch.
  Future<void> stopForPendingClockOut() async {
    await _stopStream();
  }

  Future<void> handleClockResponse(String type, Response response) async {
    final raw = response.data is Map ? response.data['data'] : null;
    final tracking = raw is Map ? raw['tracking'] : null;

    if (type == 'in') {
      if (tracking is Map) {
        await start(
          TrackingSessionState.fromJson(Map<String, dynamic>.from(tracking)),
        );
      } else {
        await restore();
      }
      return;
    }

    if (type == 'out') await stop();
  }

  Future<void> stop({bool clearSession = true}) async {
    await _stopStream();
    if (clearSession) {
      final owner = _owner;
      if (owner != null) _box.remove(_sessionKey(owner));
    }
    session.value = null;
  }

  Future<void> _stopStream() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    isTracking.value = false;
  }

  void _cacheSession(TrackingSessionState value) {
    final owner = _owner;
    if (owner == null) return;
    _box.write(
      _sessionKey(owner),
      jsonEncode({
        'id': value.id,
        'attendance_id': value.attendanceId,
        'status': value.status,
        'started_at': value.startedAt,
        'ended_at': value.endedAt,
        'last_location_at': value.lastLocationAt,
        'total_distance_meters': value.totalDistanceMeters,
      }),
    );
  }

  TrackingSessionState? _readCachedSession(String owner) {
    final raw = _box.read<String>(_sessionKey(owner));
    if (raw == null || raw.isEmpty) return null;
    try {
      return TrackingSessionState.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  @override
  void onClose() {
    _authWorker.dispose();
    _connectivityWorker.dispose();
    unawaited(_stopStream());
    super.onClose();
  }
}
