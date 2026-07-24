import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../providers/avana_api.dart';
import 'auth_service.dart';
import 'device_service.dart';

/// Firebase Cloud Messaging + local heads-up notifications. Requests permission,
/// keeps the FCM token registered for the signed-in device, and shows an
/// importance-max, sound + vibrate notification (Messenger-style) for foreground
/// messages. Background/killed messages are shown by the OS on the same channel.
class PushService extends GetxService {
  final AvanaApi _api = AvanaApi();
  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  String? _token;

  /// High-importance channel: heads-up banner + sound + vibration. The backend
  /// sends `android.notification.channel_id = avana_high` so background messages
  /// land here too.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'avana_high',
    'Notifikasi Penting',
    description:
        'Notifikasi AvanaHR: persetujuan, slip gaji, reimbursement, absensi.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  Future<void> init() async {
    await _fm.requestPermission(alert: true, badge: true, sound: true);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // Show a heads-up notification even when the app is in the foreground.
    await _fm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _fm.onTokenRefresh.listen((token) {
      _token = token;
      registerToken();
    });

    FirebaseMessaging.onMessage.listen(_showLocal);

    _token = await _fm.getToken();
    debugPrint('[FCM] getToken => ${_token ?? "NULL (Google Play services missing?)"}');
    await registerToken();
  }

  /// Push the current token to the backend for the signed-in device. No-op when
  /// logged out — re-sent right after the next login.
  Future<void> registerToken() async {
    if (!Get.find<AuthService>().isLoggedIn) {
      debugPrint('[FCM] registerToken skipped: not logged in yet');
      return;
    }

    final token = _token ?? await _fm.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[FCM] registerToken skipped: no token');
      return;
    }

    try {
      final device = await Get.find<DeviceService>().current();
      await _api.registerFcmToken(deviceId: device.deviceId, token: token);
      debugPrint('[FCM] token registered to backend (device ${device.deviceId})');
    } catch (e) {
      debugPrint('[FCM] registerToken FAILED: $e');
    }
  }

  /// Render a foreground message as a real heads-up notification (sound + vibra).
  void _showLocal(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _local.show(
      id: notification.hashCode,
      title: notification.title ?? 'AvanaHR',
      body: notification.body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
    );
  }
}
