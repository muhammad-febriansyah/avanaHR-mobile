import 'package:avanahr/app/data/models/attendance.dart';
import 'package:avanahr/app/data/models/dashboard.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two things that decide whether the clock button is offered at all:
/// the day's `next_action`, and the attendance scope the tenant puts the
/// employee under. Both were read wrong on the phone — a WFA employee was
/// held to an office radius the server never checks, and a finished day still
/// offered a clock-out the server would reject.
void main() {
  group('AttendanceToday', () {
    test('offers clock-in before the day starts', () {
      final today = AttendanceToday.fromJson({
        'date': '2026-07-31',
        'next_action': 'in',
      });

      expect(today.canClockIn, isTrue);
      expect(today.isDone, isFalse);
    });

    test('offers clock-out once clocked in', () {
      final today = AttendanceToday.fromJson({
        'date': '2026-07-31',
        'clock_in': '08:02',
        'next_action': 'out',
      });

      expect(today.canClockIn, isFalse);
      expect(today.isDone, isFalse);
    });

    test('offers nothing once both clocks are recorded', () {
      final today = AttendanceToday.fromJson({
        'date': '2026-07-31',
        'clock_in': '08:02',
        'clock_out': '17:10',
        'next_action': 'done',
      });

      expect(today.canClockIn, isFalse);
      expect(today.isDone, isTrue);
    });

    test('offline optimistic updates preserve attendance requirements', () {
      final today = AttendanceToday.fromJson(
        {'date': '2026-07-31', 'work_date': '2026-07-31', 'next_action': 'in'},
        requirements: {
          'timezone': 'Asia/Makassar',
          'timezone_label': 'WITA',
          'face_mode': 'detection',
          'require_liveness_challenge': true,
          'wfh_approved_today': true,
        },
      );

      final queued = today.copyWith(
        nextAction: 'out',
        clockIn: '08:10',
        workMode: 'home',
        pendingSync: true,
      );

      expect(queued.workDate, '2026-07-31');
      expect(queued.timezone, 'Asia/Makassar');
      expect(queued.timezoneLabel, 'WITA');
      expect(queued.faceMode, 'detection');
      expect(queued.requiresLivenessChallenge, isTrue);
      expect(queued.wfhApprovedToday, isTrue);
      expect(queued.workMode, 'home');
      expect(queued.pendingSync, isTrue);
    });
  });

  test('DashboardSummary keeps monthly statuses mutually exclusive', () {
    final summary = DashboardSummary.fromJson({
      'attendance_month': {
        'present': 10,
        'late': 2,
        'absent': 1,
        'incomplete': 3,
      },
    });

    expect(summary.presentDays, 10);
    expect(summary.lateDays, 2);
    expect(summary.absentDays, 1);
    expect(summary.incompleteDays, 3);
  });

  group('AttendanceToday requirements', () {
    test('reads the tenant policy the punch has to satisfy', () {
      final today = AttendanceToday.fromJson(
        {'date': '2026-07-31', 'next_action': 'in'},
        requirements: {
          'face_mode': 'detection',
          'device_binding_enabled': false,
          'require_face_enrollment': true,
          'require_liveness_challenge': true,
          'wfh_approved_today': true,
        },
      );

      expect(today.faceMode, 'detection');
      expect(today.requiresFaceCapture, isTrue);
      expect(today.usesFaceRecognition, isFalse);
      expect(today.deviceBindingEnabled, isFalse);
      expect(today.requiresFaceEnrollment, isTrue);
      expect(today.requiresLivenessChallenge, isTrue);
      expect(today.wfhApprovedToday, isTrue);
    });

    test('reads whether a failed face blocks the punch or only flags it', () {
      final flagging = AttendanceToday.fromJson(
        {'date': '2026-07-31', 'next_action': 'in'},
        requirements: {'face_enforcement': 'flag'},
      );

      // Under "flag" the server records the punch and marks it for review, so
      // the app must not refuse one the tenant's own policy accepts.
      expect(flagging.faceEnforcement, 'flag');
      expect(flagging.blocksOnFaceFailure, isFalse);

      final blocking = AttendanceToday.fromJson(
        {'date': '2026-07-31', 'next_action': 'in'},
        requirements: {'face_enforcement': 'block'},
      );

      expect(blocking.blocksOnFaceFailure, isTrue);
    });

    test('blocks on face failure when the server names no enforcement', () {
      final today = AttendanceToday.fromJson({
        'date': '2026-07-31',
        'next_action': 'in',
      });

      // An older server, or a dropped field, must never be read as permission
      // to skip the face check.
      expect(today.blocksOnFaceFailure, isTrue);
    });

    test('optimistic updates keep the enforcement the tenant set', () {
      final today = AttendanceToday.fromJson(
        {'date': '2026-07-31', 'next_action': 'in'},
        requirements: {'face_enforcement': 'flag'},
      );

      expect(today.copyWith(nextAction: 'out').blocksOnFaceFailure, isFalse);
    });

    test('leaves the optional gates off when the tenant has not asked', () {
      final today = AttendanceToday.fromJson(
        {'date': '2026-07-31', 'next_action': 'in'},
        requirements: {'face_mode': 'off'},
      );

      // The defaults decide whether the app asks for a nonce and whether it
      // makes enrolment a precondition — neither may be assumed on.
      expect(today.requiresLivenessChallenge, isFalse);
      expect(today.requiresFaceEnrollment, isFalse);
      expect(today.requiresFaceCapture, isFalse);
      // Binding, in contrast, is on unless the tenant turned it off.
      expect(today.deviceBindingEnabled, isTrue);
    });
  });

  group('WorkLocations', () {
    test('reads WFA from the scope, not from an empty office list', () {
      const wfa = WorkLocations(
        items: [
          WorkLocationItem(
            id: 1,
            name: 'Kantor Pusat Jakarta',
            radius: 100,
            latitude: -6.2,
            longitude: 106.8,
          ),
        ],
        scope: 'anywhere',
      );

      // The offices still travel under WFA so the app can name the nearest.
      expect(wfa.items, hasLength(1));
      expect(wfa.isAnywhere, isTrue);
    });

    test('treats assigned and any_branch as fenced', () {
      expect(
        const WorkLocations(items: [], scope: 'assigned').isAnywhere,
        isFalse,
      );
      expect(
        const WorkLocations(items: [], scope: 'any_branch').isAnywhere,
        isFalse,
      );
    });

    test('falls back to the fenced scope when the server sends none', () {
      expect(const WorkLocations(items: []).isAnywhere, isFalse);
    });
  });
}
