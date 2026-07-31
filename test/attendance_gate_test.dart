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
