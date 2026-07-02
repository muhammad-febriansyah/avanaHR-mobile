import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Thin wrapper over GetStorage for the few values we persist locally:
/// the JWT and the "onboarding seen" flag.
class StorageService extends GetxService {
  final _box = GetStorage();

  static const _kToken = 'access_token';
  static const _kOnboarded = 'onboarded';
  static const _kRememberEmail = 'remember_email';

  String? get token => _box.read<String>(_kToken);
  bool get hasToken => (token ?? '').isNotEmpty;
  bool get onboarded => _box.read<bool>(_kOnboarded) ?? false;

  /// Email kept for the "Ingat saya" toggle on the login screen.
  String? get rememberedEmail => _box.read<String>(_kRememberEmail);

  Future<void> saveToken(String token) => _box.write(_kToken, token);
  Future<void> clearToken() => _box.remove(_kToken);
  Future<void> setOnboarded() => _box.write(_kOnboarded, true);
  Future<void> clearOnboarded() => _box.remove(_kOnboarded);
  Future<void> saveRememberedEmail(String email) => _box.write(_kRememberEmail, email);
  Future<void> clearRememberedEmail() => _box.remove(_kRememberEmail);
}
