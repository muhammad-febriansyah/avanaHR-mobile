import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Local persistence for the few values the app keeps between launches.
///
/// The JWT lives in the platform keystore — Keychain on iOS,
/// EncryptedSharedPreferences on Android — rather than beside the rest.
/// GetStorage writes plain JSON into the app's documents directory, readable by
/// anything with filesystem access on a rooted or jailbroken phone, and that
/// file held a credential good until it expired. The other values here (an
/// onboarding flag, a remembered email) are worth nothing to a thief and stay
/// where they were.
class StorageService extends GetxService {
  final _box = GetStorage();
  // Android needs no options: the plugin encrypts with its own ciphers now.
  // iOS is told the Keychain item may be read once the device has been unlocked
  // since boot, so a background refresh does not fail on a locked phone.
  final _secure = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _kToken = 'access_token';
  static const _kOnboarded = 'onboarded';
  static const _kRememberEmail = 'remember_email';
  static const _kMoodPromptDate = 'mood_prompt_date';

  /// The token, mirrored in memory.
  ///
  /// Secure storage is async, but the Dio interceptor needs the token while it
  /// is building a request. So it is read once at startup and kept here; every
  /// write goes to both, so the two cannot drift.
  String? _token;

  /// Load the token, moving an older plaintext one across on the way.
  ///
  /// Awaited by `Get.putAsync` in main, so nothing reads a token before it is
  /// in place.
  Future<StorageService> init() async {
    _token = await _secure.read(key: _kToken);

    final legacy = _box.read<String>(_kToken);

    // Installed before this change: the token is still in GetStorage. Move it
    // rather than signing everybody out, then erase the plaintext copy.
    if (_token == null && legacy != null && legacy.isNotEmpty) {
      await _secure.write(key: _kToken, value: legacy);
      _token = legacy;
    }

    if (legacy != null) {
      await _box.remove(_kToken);
    }

    return this;
  }

  String? get token => _token;

  bool get hasToken => (_token ?? '').isNotEmpty;

  bool get onboarded => _box.read<bool>(_kOnboarded) ?? false;

  /// Email kept for the "Ingat saya" toggle on the login screen.
  String? get rememberedEmail => _box.read<String>(_kRememberEmail);

  /// Last date (yyyy-MM-dd) the daily mood popup was auto-shown — so it prompts
  /// at most once per calendar day, even if the user dismissed it.
  String? get moodPromptDate => _box.read<String>(_kMoodPromptDate);

  Future<void> saveToken(String token) async {
    _token = token;
    await _secure.write(key: _kToken, value: token);
  }

  Future<void> clearToken() async {
    _token = null;
    await _secure.delete(key: _kToken);
    // Belt and braces for an install that never ran the migration above.
    await _box.remove(_kToken);
  }

  Future<void> setOnboarded() => _box.write(_kOnboarded, true);

  Future<void> clearOnboarded() => _box.remove(_kOnboarded);

  Future<void> saveRememberedEmail(String email) =>
      _box.write(_kRememberEmail, email);

  Future<void> clearRememberedEmail() => _box.remove(_kRememberEmail);

  Future<void> setMoodPromptDate(String date) =>
      _box.write(_kMoodPromptDate, date);
}
