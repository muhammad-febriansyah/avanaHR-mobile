import 'package:avanahr/app/modules/main/main_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Style 13 asserts an odd item count and promotes whichever item sits at the
/// middle position to its floating circle. Since the bar now comes from the
/// server, neither is guaranteed, and getting it wrong crashed the shell with
/// "The number of items must be odd for this style".
void main() {
  group('MainController.absensiIsCentred', () {
    test('the shipped five-tab bar puts Absensi in the middle', () {
      expect(
        MainController.absensiIsCentred(MainController.fallbackTabKeys),
        isTrue,
      );
    });

    test('a company that switches one tab off leaves an even bar', () {
      // Four tabs would trip Style 13's odd-count assertion.
      expect(
        MainController.absensiIsCentred([
          'beranda',
          'absensi',
          'pengumuman',
          'profil',
        ]),
        isFalse,
      );
    });

    test('an odd bar with Absensi off centre does not claim the circle', () {
      // Odd, so the assertion would pass — but the circle would land on
      // 'pengumuman', which has no icon prepared to be one.
      expect(
        MainController.absensiIsCentred([
          'absensi',
          'beranda',
          'pengumuman',
        ]),
        isFalse,
      );
    });

    test('a bar without Absensi at all never claims the circle', () {
      expect(
        MainController.absensiIsCentred(['beranda', 'sosmed', 'profil']),
        isFalse,
      );
    });

    test('Absensi alone is centred', () {
      expect(MainController.absensiIsCentred(['absensi']), isTrue);
    });

    test('an empty bar does not claim the circle', () {
      expect(MainController.absensiIsCentred([]), isFalse);
    });

    test('a three-tab bar with Absensi in the middle keeps the circle', () {
      expect(
        MainController.absensiIsCentred(['beranda', 'absensi', 'profil']),
        isTrue,
      );
    });
  });
}
