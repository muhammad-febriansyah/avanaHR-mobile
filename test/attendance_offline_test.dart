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
    test('recognition is punchable offline once enrolled', () {
      // The scan runs on the phone and the frame travels with the queued punch;
      // the server matches it on arrival. Blocking here used to make offline
      // attendance impossible for every tenant, since all of them run
      // recognition.
      expect(
        AttendanceController.faceNeedsNetwork(
          day({
            'face_mode': 'recognition',
            'face_enforcement': 'block',
            'require_face_enrollment': true,
          }),
          isEnrolled: true,
        ),
        isFalse,
      );
    });

    test('an unenrolled employee cannot punch offline', () {
      // The template lives on the server, so there is nothing to match against
      // and nothing the phone can do about it.
      expect(
        AttendanceController.faceNeedsNetwork(
          day({
            'face_mode': 'recognition',
            'face_enforcement': 'block',
            'require_face_enrollment': true,
          }),
          isEnrolled: false,
        ),
        isTrue,
      );
    });

    test(
      'enrolment that is not required does not block an unenrolled punch',
      () {
        expect(
          AttendanceController.faceNeedsNetwork(
            day({
              'face_mode': 'recognition',
              'face_enforcement': 'block',
              'require_face_enrollment': false,
            }),
            isEnrolled: false,
          ),
          isFalse,
        );
      },
    );

    test('a liveness challenge always needs the server', () {
      // Its nonce has to be minted live; fetching one at sync would prove
      // nothing about when the punch was made.
      expect(
        AttendanceController.faceNeedsNetwork(
          day({'face_mode': 'off', 'require_liveness_challenge': true}),
          isEnrolled: true,
        ),
        isTrue,
      );
    });

    test('face off can be punched without a server', () {
      expect(
        AttendanceController.faceNeedsNetwork(
          day({'face_mode': 'off'}),
          isEnrolled: false,
        ),
        isFalse,
      );
    });

    test('an unfetched policy is treated as strict', () {
      expect(
        AttendanceController.faceNeedsNetwork(null, isEnrolled: true),
        isTrue,
      );
    });
  });

  group('offlineBlockMessage', () {
    final recognition = day({
      'face_mode': 'recognition',
      'face_enforcement': 'block',
      'require_face_enrollment': true,
    });

    test('says nothing while online', () {
      expect(
        AttendanceController.offlineBlockMessage(
          status: ConnStatus.online,
          day: recognition,
          isEnrolled: false,
        ),
        isNull,
      );
    });

    test('says nothing offline once the punch can be queued', () {
      expect(
        AttendanceController.offlineBlockMessage(
          status: ConnStatus.offline,
          day: recognition,
          isEnrolled: true,
        ),
        isNull,
      );
    });

    test('points an unenrolled employee at enrolling, not at the scan', () {
      final message = AttendanceController.offlineBlockMessage(
        status: ConnStatus.offline,
        day: recognition,
        isEnrolled: false,
      );

      expect(message, contains('Daftarkan wajah'));
      // The old copy blamed the scan itself, which runs on the phone.
      expect(message, isNot(contains('Verifikasi wajah butuh koneksi')));
    });

    test('distinguishes a dead network from no network at all', () {
      expect(
        AttendanceController.offlineBlockMessage(
          status: ConnStatus.unstable,
          day: recognition,
          isEnrolled: false,
        ),
        contains('tidak stabil'),
      );
    });

    test('names the liveness challenge as the obstacle when it is one', () {
      final message = AttendanceController.offlineBlockMessage(
        status: ConnStatus.offline,
        day: day({'face_mode': 'off', 'require_liveness_challenge': true}),
        isEnrolled: true,
      );

      expect(message, contains('verifikasi langsung ke server'));
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
