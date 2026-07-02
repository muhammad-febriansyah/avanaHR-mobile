import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../models/user.dart';
import '../providers/api_client.dart';
import '../providers/avana_api.dart';
import 'device_service.dart';
import 'storage_service.dart';

/// Holds the authenticated session: the JWT (via StorageService) and the
/// current [AppUser]. Exposed app-wide as a permanent GetxService.
class AuthService extends GetxService {
  final _api = AvanaApi();
  final StorageService _storage = Get.find();

  final Rxn<AppUser> user = Rxn<AppUser>();

  bool get isLoggedIn => _storage.hasToken;
  bool get isManager => user.value?.isManager ?? false;

  /// Returns null on success, otherwise an error message.
  Future<String?> login(String email, String password) async {
    try {
      final device = await Get.find<DeviceService>().current();
      final res = await _api.login(email, password, device: device.toJson());
      if (res.statusCode == 200 && res.data['access_token'] != null) {
        await _storage.saveToken(res.data['access_token']);
        user.value = AppUser.fromJson(Map<String, dynamic>.from(res.data['user']));
        return null;
      }
      return ApiClient.messageFrom(res, 'Email atau kata sandi salah.');
    } on DioException catch (e) {
      return ApiClient.messageFrom(e.response, 'Gagal terhubung ke server.');
    }
  }

  /// Refresh the current user from /auth/me. Returns false if the token is dead.
  Future<bool> loadMe() async {
    try {
      user.value = await _api.me();
      return true;
    } on DioException {
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // Ignore network errors on logout — clear the session regardless.
    }
    await _storage.clearToken();
    user.value = null;
  }
}
