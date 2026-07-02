import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart' hide Response;

import '../../core/widgets/app_toast.dart';
import '../../data/models/attendance.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';
import '../../data/services/attendance_queue_service.dart';
import '../../data/services/connectivity_service.dart';
import '../../data/services/device_service.dart';

class AttendanceController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final isClocking = false.obs;
  final today = Rxn<AttendanceToday>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      today.value = await _api.attendanceToday();
    } catch (_) {
      today.value = null;
    }
    isLoading.value = false;
  }

  Future<void> clock() async {
    final type = today.value?.canClockIn ?? true ? 'in' : 'out';
    isClocking.value = true;
    try {
      final pos = await _currentPosition();
      final deviceService = Get.find<DeviceService>();
      final device = await deviceService.current();
      final isRooted = await deviceService.isCompromised();

      final entry = <String, dynamic>{
        'type': type,
        'latitude': pos?.latitude,
        'longitude': pos?.longitude,
        'device_id': device.deviceId,
        'is_mock_location': pos?.isMocked ?? false,
        'is_rooted': isRooted,
        'clocked_at': DateTime.now().toIso8601String(),
      };

      // No internet → queue it and reflect the action locally.
      if (!Get.find<ConnectivityService>().online.value) {
        _queueOffline(type, entry);
        return;
      }

      try {
        final res = await _api.clock(
          type: type,
          latitude: pos?.latitude,
          longitude: pos?.longitude,
          faceConfidence: 0.95, // placeholder until on-device face match lands
          deviceId: device.deviceId,
          isMockLocation: pos?.isMocked ?? false,
          isRooted: isRooted,
        );
        final code = res.statusCode ?? 0;
        if (code >= 200 && code < 300) {
          AppToast.success(ApiClient.messageFrom(res, 'Absensi tercatat.'));
          await load();
        } else {
          AppToast.error(ApiClient.messageFrom(res, 'Gagal mencatat absensi.'));
        }
      } on DioException catch (e) {
        // Lost connection mid-request → fall back to the offline queue.
        if (_isNetworkError(e)) {
          _queueOffline(type, entry);
        } else {
          AppToast.error(ApiClient.errorMessage(e));
        }
      }
    } finally {
      isClocking.value = false;
    }
  }

  void _queueOffline(String type, Map<String, dynamic> entry) {
    Get.find<AttendanceQueueService>().enqueue(entry);
    _applyOptimistic(type);
    AppToast.info('Tidak ada internet. Absen disimpan & dikirim otomatis saat online.');
  }

  bool _isNetworkError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout;

  /// Reflect a queued clock action in today's status immediately.
  void _applyOptimistic(String type) {
    final now = DateTime.now();
    final hm = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final t = today.value;
    final date = t?.date ?? now.toIso8601String().split('T').first;

    if (type == 'in') {
      today.value = AttendanceToday(date: date, nextAction: 'out', clockIn: hm, clockOut: t?.clockOut, status: 'present', workMinutes: t?.workMinutes ?? 0);
    } else {
      today.value = AttendanceToday(date: date, nextAction: 'done', clockIn: t?.clockIn, clockOut: hm, status: t?.status, workMinutes: t?.workMinutes ?? 0);
    }
  }

  /// Best-effort GPS; returns null if permission denied or location off.
  Future<Position?> _currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }
}
