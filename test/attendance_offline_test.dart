import 'package:avanahr/app/core/widgets/app_toast.dart';
import 'package:avanahr/app/data/models/attendance.dart';
import 'package:avanahr/app/data/services/connectivity_service.dart';
import 'package:avanahr/app/modules/attendance/attendance_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Offline behaviour on the attendance screen.
///
/// Being offline used to surface only as a toast fired after a tap that went
/// nowhere: the button stayed lit, two taps stacked two identical banners, and
/// nothing on the screen said whether the punch had been stored or lost. These
/// cover the rule that now decides all of it.
AttendanceToday day(Map<String, dynamic> requirements) =>
    AttendanceToday.fromJson(const {
      'date': '2026-08-28',
      'next_action': 'in',
    }, requirements: requirements);

void main() {
  group('faceNeedsNetwork', () {
    test('recognition always needs the server', () {
      expect(
        AttendanceController.faceNeedsNetwork(
          day({
            'face_mode': 'recognition',
            'face_enforcement': 'flag',
            'require_face_enrollment': false,
          }),
        ),
        isTrue,
      );
    });

    test('a blocking policy needs the server even in detection mode', () {
      expect(
        AttendanceController.faceNeedsNetwork(
          day({
            'face_mode': 'detection',
            'face_enforcement': 'block',
            'require_face_enrollment': false,
          }),
        ),
        isTrue,
      );
    });

    test('enrolment needs the server', () {
      expect(
        AttendanceController.faceNeedsNetwork(
          day({
            'face_mode': 'detection',
            'face_enforcement': 'flag',
            'require_face_enrollment': true,
          }),
        ),
        isTrue,
      );
    });

    test('face off can be punched without a server', () {
      expect(
        AttendanceController.faceNeedsNetwork(
          day({
            'face_mode': 'off',
            'face_enforcement': 'flag',
            'require_face_enrollment': false,
          }),
        ),
        isFalse,
      );
    });

    test('detection that only flags can be punched without a server', () {
      expect(
        AttendanceController.faceNeedsNetwork(
          day({
            'face_mode': 'detection',
            'face_enforcement': 'flag',
            'require_face_enrollment': false,
          }),
        ),
        isFalse,
      );
    });

    test('an unfetched policy is treated as strict', () {
      expect(AttendanceController.faceNeedsNetwork(null), isTrue);
    });
  });

  group('offlineBlockMessage', () {
    test('says nothing while online', () {
      expect(
        AttendanceController.offlineBlockMessage(
          status: ConnStatus.online,
          requiresOnlineFace: true,
        ),
        isNull,
      );
    });

    test('says nothing offline when the punch can be queued', () {
      expect(
        AttendanceController.offlineBlockMessage(
          status: ConnStatus.offline,
          requiresOnlineFace: false,
        ),
        isNull,
      );
    });

    test('blocks an offline punch that needs face verification', () {
      expect(
        AttendanceController.offlineBlockMessage(
          status: ConnStatus.offline,
          requiresOnlineFace: true,
        ),
        contains('Tidak ada internet'),
      );
    });

    test('distinguishes a dead network from no network at all', () {
      final message = AttendanceController.offlineBlockMessage(
        status: ConnStatus.unstable,
        requiresOnlineFace: true,
      );

      expect(message, contains('tidak stabil'));
      expect(message, isNot(contains('Tidak ada internet')));
    });
  });

  group('queuesWhileOffline', () {
    test('queues when offline and the face gate allows it', () {
      expect(
        AttendanceController.queuesWhileOffline(
          status: ConnStatus.offline,
          requiresOnlineFace: false,
        ),
        isTrue,
      );
    });

    test('queues on an unstable link too — the request will not land', () {
      expect(
        AttendanceController.queuesWhileOffline(
          status: ConnStatus.unstable,
          requiresOnlineFace: false,
        ),
        isTrue,
      );
    });

    test('never queues a punch that needs the server', () {
      expect(
        AttendanceController.queuesWhileOffline(
          status: ConnStatus.offline,
          requiresOnlineFace: true,
        ),
        isFalse,
      );
    });

    test('never queues while online', () {
      expect(
        AttendanceController.queuesWhileOffline(
          status: ConnStatus.online,
          requiresOnlineFace: false,
        ),
        isFalse,
      );
    });
  });

  group('AppToast', () {
    setUp(AppToast.reset);

    test('suppresses a repeat of a message still on screen', () {
      expect(AppToast.debugWouldShow('Tidak ada internet.'), isTrue);
      expect(AppToast.debugWouldShow('Tidak ada internet.'), isFalse);
    });

    test('lets a different message through', () {
      expect(AppToast.debugWouldShow('Tidak ada internet.'), isTrue);
      expect(AppToast.debugWouldShow('GPS mati.'), isTrue);
    });
  });
}
