import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_storage/get_storage.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../models/user.dart';
import '../providers/api_client.dart';
import '../providers/avana_api.dart';
import 'device_service.dart';
import 'push_service.dart';
import 'storage_service.dart';

/// GetStorage keys for the cached tenant brand (applied at cold start so the
/// splash is tenant-branded on every launch after the first login).
const String kBrandAccentKey = 'brand_accent';
const String kBrandNameKey = 'brand_name';
const String kBrandLogoKey = 'brand_logo';

/// What a sign-in attempt came back with: a session, a request for the second
/// factor, or a message to show.
class LoginResult {
  /// Set when the attempt failed and the user needs telling why.
  final String? error;

  /// Set when the password was right but the account carries a second factor.
  /// Trade it, with a code, through [AuthService.verifyTwoFactor].
  final String? challengeToken;

  const LoginResult._({this.error, this.challengeToken});

  const LoginResult.success() : this._();
  const LoginResult.failed(String message) : this._(error: message);
  const LoginResult.twoFactorRequired(String token) : this._(challengeToken: token);

  bool get isSuccess => error == null && challengeToken == null;
  bool get needsTwoFactor => challengeToken != null;
}

/// What the second-factor exchange came back with.
class TwoFactorResult {
  /// Set when the exchange failed and the user needs telling why.
  final String? error;

  /// True when the challenge itself is gone — spent, timed out, or given up on
  /// after too many wrong codes. Only a fresh password mints another, so the
  /// screen has nothing left to retry and should send the user back to login.
  final bool challengeExpired;

  const TwoFactorResult._({this.error, this.challengeExpired = false});

  const TwoFactorResult.success() : this._();
  const TwoFactorResult.failed(String message) : this._(error: message);
  const TwoFactorResult.expired(String message)
    : this._(error: message, challengeExpired: true);

  bool get isSuccess => error == null;
}

/// Holds the authenticated session: the JWT (via StorageService) and the
/// current [AppUser]. Exposed app-wide as a permanent GetxService.
class AuthService extends GetxService {
  final _api = AvanaApi();
  final StorageService _storage = Get.find();

  final Rxn<AppUser> user = Rxn<AppUser>();

  bool get isLoggedIn => _storage.hasToken;
  bool get isManager => user.value?.isManager ?? false;

  Future<LoginResult> login(String email, String password) async {
    try {
      final device = await Get.find<DeviceService>().current();
      final res = await _api.login(email, password, device: device.toJson());

      // The password was right, but this account asks for a code as well. No
      // token yet — the challenge is the only thing worth keeping.
      if (res.statusCode == 200 && res.data['two_factor_required'] == true) {
        final token = res.data['challenge_token'];
        if (token is String && token.isNotEmpty) {
          return LoginResult.twoFactorRequired(token);
        }
      }

      if (res.statusCode == 200 && res.data['access_token'] != null) {
        await _openSession(res.data);
        return const LoginResult.success();
      }
      return LoginResult.failed(
        ApiClient.messageFrom(res, 'Email atau kata sandi salah.'),
      );
    } on DioException catch (e) {
      return LoginResult.failed(ApiClient.errorMessage(e));
    }
  }

  /// Trade a login challenge plus a code for the session it is holding back.
  ///
  /// Pass exactly one of [code] (from the authenticator app) or [recoveryCode].
  Future<TwoFactorResult> verifyTwoFactor(
    String challengeToken, {
    String? code,
    String? recoveryCode,
  }) async {
    try {
      final res = await _api.twoFactor(
        challengeToken,
        code: code,
        recoveryCode: recoveryCode,
      );
      if (res.statusCode == 200 && res.data['access_token'] != null) {
        await _openSession(res.data);
        return const TwoFactorResult.success();
      }

      // Anything under 500 arrives here as a response rather than a throw, so
      // the status is read off it: 401 is the server saying the challenge is
      // gone, while 422 is a wrong code the same challenge still has attempts
      // left for.
      final message = ApiClient.messageFrom(res, 'Kode verifikasi tidak valid.');

      return res.statusCode == 401
          ? TwoFactorResult.expired(message)
          : TwoFactorResult.failed(message);
    } on DioException catch (e) {
      // Transport failures and 5xx only — the app never reached the server, so
      // the challenge is presumed still good and the code worth retyping.
      return TwoFactorResult.failed(ApiClient.errorMessage(e));
    }
  }

  /// Store the token and user from a login or challenge response, then brand
  /// the app to the tenant behind them.
  Future<void> _openSession(dynamic data) async {
    await _storage.saveToken(data['access_token']);
    user.value = AppUser.fromJson(Map<String, dynamic>.from(data['user']));
    _applyTenantBrand();
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

    // Now that a session exists, push the device's FCM token to the backend.
    if (Get.isRegistered<PushService>()) {
      Get.find<PushService>().registerToken();
    }
  }
}
