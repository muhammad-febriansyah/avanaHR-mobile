import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart' hide Response;

import '../../core/widgets/app_toast.dart';
import '../../data/models/attendance.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';
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
      final res = await _api.clock(
        type: type,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        faceConfidence: 0.95, // placeholder until on-device face match lands
        deviceId: device.deviceId,
        isMockLocation: pos?.isMocked ?? false,
        isRooted: isRooted,
      );
      if (res.statusCode == 201) {
        AppToast.success(ApiClient.messageFrom(res, 'Absensi tercatat.'));
        await load();
      } else {
        AppToast.error(ApiClient.messageFrom(res, 'Gagal mencatat absensi.'));
      }
    } on DioException catch (e) {
      AppToast.error(ApiClient.messageFrom(e.response, 'Gagal terhubung ke server.'));
    } finally {
      isClocking.value = false;
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
