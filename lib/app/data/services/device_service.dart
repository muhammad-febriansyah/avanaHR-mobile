import 'dart:io' show Platform;
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

/// Identity + metadata of the physical device, sent to the API for
/// single-device binding and recorded server-side.
class DeviceMeta {
  const DeviceMeta({
    required this.deviceId,
    required this.platform,
    required this.model,
    required this.osVersion,
    required this.deviceName,
    required this.appVersion,
  });

  final String deviceId;
  final String platform;
  final String model;
  final String osVersion;
  final String deviceName;
  final String appVersion;

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'platform': platform,
        'model': model,
        'os_version': osVersion,
        'device_name': deviceName,
        'app_version': appVersion,
      };
}

/// Resolves a stable per-install device id (persisted in secure storage so it
/// survives app restarts) plus human-readable hardware details.
class DeviceService extends GetxService {
  static const _kDeviceId = 'avana_device_id';
  static const _appVersion = '1.0.0';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final DeviceInfoPlugin _info = DeviceInfoPlugin();

  DeviceMeta? _cached;

  /// The device metadata, resolved once and cached for the session.
  Future<DeviceMeta> current() async {
    if (_cached != null) return _cached!;

    final id = await _deviceId();
    var platform = 'unknown';
    var model = 'Perangkat';
    var osVersion = '';
    var name = '';

    try {
      if (Platform.isAndroid) {
        final a = await _info.androidInfo;
        platform = 'android';
        model = '${a.manufacturer} ${a.model}'.trim();
        osVersion = 'Android ${a.version.release}';
        name = a.model;
      } else if (Platform.isIOS) {
        final i = await _info.iosInfo;
        platform = 'ios';
        model = i.utsname.machine;
        osVersion = 'iOS ${i.systemVersion}';
        name = i.name;
      }
    } catch (_) {
      // Fall back to the generic defaults above if device info is unavailable.
    }

    _cached = DeviceMeta(
      deviceId: id,
      platform: platform,
      model: model,
      osVersion: osVersion,
      deviceName: name,
      appVersion: _appVersion,
    );
    return _cached!;
  }

  /// True when the device appears rooted (Android) or jailbroken (iOS).
  /// Best-effort — returns false if the check is unavailable.
  Future<bool> isCompromised() async {
    try {
      return await FlutterJailbreakDetection.jailbroken;
    } catch (_) {
      return false;
    }
  }

  Future<String> _deviceId() async {
    final existing = await _secure.read(key: _kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;

    final rand = Random.secure();
    final id = List<int>.generate(16, (_) => rand.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    await _secure.write(key: _kDeviceId, value: id);
    return id;
  }
}
