import 'dart:io';

import 'package:avanahr/app/data/services/storage_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

/// Stands in for the Keychain / Android keystore so the migration can be tested
/// without a device.
class _FakeSecureStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> values = {};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => values[key] = value;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => values[key];

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => values.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => values.remove(key);

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(values);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      values.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSecureStorage secure;
  late Directory temp;

  setUp(() async {
    secure = _FakeSecureStorage();
    FlutterSecureStoragePlatform.instance = secure;

    // GetStorage asks path_provider where to write; there is no plugin host in
    // a unit test, so it is pointed at a throwaway directory instead.
    temp = await Directory.systemTemp.createTemp('avanahr_storage_test');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => temp.path,
        );

    await GetStorage.init();
    await GetStorage().erase();
  });

  tearDown(() async {
    if (temp.existsSync()) {
      await temp.delete(recursive: true);
    }
  });

  group('StorageService token', () {
    test('moves a token left in plaintext by an older build', () async {
      // What an install from before this change looks like.
      await GetStorage().write('access_token', 'jwt-lama');

      final service = await StorageService().init();

      expect(service.token, 'jwt-lama');
      expect(service.hasToken, isTrue);
      // Now in the keystore…
      expect(secure.values['access_token'], 'jwt-lama');
      // …and gone from the plaintext file, which is the point of the exercise.
      expect(GetStorage().read('access_token'), isNull);
    });

    test('a returning user is not signed out by the move', () async {
      await GetStorage().write('access_token', 'jwt-lama');
      await StorageService().init();

      // Second launch: nothing left in GetStorage, token read from the keystore.
      final second = await StorageService().init();

      expect(second.hasToken, isTrue);
      expect(second.token, 'jwt-lama');
    });

    test('writes only to the keystore from now on', () async {
      final service = await StorageService().init();

      await service.saveToken('jwt-baru');

      expect(service.token, 'jwt-baru');
      expect(secure.values['access_token'], 'jwt-baru');
      expect(GetStorage().read('access_token'), isNull);
    });

    test('clearing forgets it everywhere, in memory first', () async {
      final service = await StorageService().init();
      await service.saveToken('jwt-baru');

      await service.clearToken();

      expect(service.token, isNull);
      expect(service.hasToken, isFalse);
      expect(secure.values.containsKey('access_token'), isFalse);
    });

    test('a fresh install simply has no token', () async {
      final service = await StorageService().init();

      expect(service.token, isNull);
      expect(service.hasToken, isFalse);
    });

    test(
      'leaves the values that were never sensitive where they were',
      () async {
        final service = await StorageService().init();

        await service.setOnboarded();
        await service.saveRememberedEmail('budi@contoh.test');

        // Still in GetStorage: neither is worth anything to a thief, and moving
        // them would cost a keystore round trip on every launch.
        expect(GetStorage().read('onboarded'), isTrue);
        expect(GetStorage().read('remember_email'), 'budi@contoh.test');
        expect(service.rememberedEmail, 'budi@contoh.test');
      },
    );
  });
}
