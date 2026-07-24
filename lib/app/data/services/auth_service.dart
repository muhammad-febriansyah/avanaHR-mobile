import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_storage/get_storage.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../models/user.dart';
import '../providers/api_client.dart';
import '../providers/avana_api.dart';
import 'device_service.dart';
import 'storage_service.dart';

/// GetStorage keys for the cached tenant brand (applied at cold start so the
/// splash is tenant-branded on every launch after the first login).
const String kBrandAccentKey = 'brand_accent';
const String kBrandNameKey = 'brand_name';
const String kBrandLogoKey = 'brand_logo';

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
        user.value = AppUser.fromJson(
          Map<String, dynamic>.from(res.data['user']),
        );
        _applyTenantBrand();
        return null;
      }
      return ApiClient.messageFrom(res, 'Email atau kata sandi salah.');
    } on DioException catch (e) {
      return ApiClient.errorMessage(e);
    }
  }

  /// Refresh the current user from /auth/me. Returns false if the token is dead.
  Future<bool> loadMe() async {
    try {
      user.value = await _api.me();
      _applyTenantBrand();
      return true;
    } catch (_) {
      // Dead/absent token, network error, or an unexpected response shape:
      // treat all as "not authenticated" so the splash routes to login instead
      // of throwing an unhandled exception.
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
    // Reset onboarding so a logged-out user sees the intro again on next launch.
    await _storage.clearOnboarded();
    user.value = null;

    // Drop the tenant brand back to the AvanaHR default.
    final box = GetStorage();
    box.remove(kBrandAccentKey);
    box.remove(kBrandNameKey);
    box.remove(kBrandLogoKey);
    AppColors.applyBrand(null);
    Get.changeTheme(AppTheme.light);
  }

  /// Re-brand the whole app to the signed-in tenant's accent colour and cache
  /// the brand (accent + name + logo) so the next cold start applies it before
  /// the first frame and the splash shows the tenant, not AvanaHR.
  void _applyTenantBrand() {
    final hex = user.value?.tenantAccentHex;
    final name = user.value?.tenantName;
    final logo = user.value?.tenantLogoUrl;
    final box = GetStorage();
    // Only overwrite a cached brand with a real value — never wipe it back to
    // null if a response is briefly missing the tenant, so the launch splash
    // stays tenant-branded across cold starts / hot restarts.
    if (hex != null && hex.isNotEmpty) box.write(kBrandAccentKey, hex);
    if (name != null && name.isNotEmpty) box.write(kBrandNameKey, name);
    if (logo != null && logo.isNotEmpty) box.write(kBrandLogoKey, logo);
    AppColors.applyBrand(hex);
    Get.changeTheme(AppTheme.light);
  }
}
