import 'package:avanahr/app/data/models/two_factor_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TwoFactorStatus', () {
    test('an untouched account offers nothing to leak', () {
      final status = TwoFactorStatus.fromJson({
        'enabled': false,
        'confirming': false,
        'qr_svg': null,
        'setup_key': null,
        'setup_url': null,
        'recovery_codes': [],
      });

      expect(status.enabled, isFalse);
      expect(status.confirming, isFalse);
      expect(status.setupKey, isNull);
      expect(status.recoveryCodes, isEmpty);
    });

    test('an enrolment in progress carries the QR and the key, not the codes', () {
      final status = TwoFactorStatus.fromJson({
        'enabled': false,
        'confirming': true,
        'qr_svg': '<svg></svg>',
        'setup_key': 'JBSWY3DPEHPK3PXP',
        'setup_url': 'otpauth://totp/AvanaHR:budi',
        'recovery_codes': [],
      });

      expect(status.confirming, isTrue);
      expect(status.enabled, isFalse);
      expect(status.qrSvg, '<svg></svg>');
      expect(status.setupKey, 'JBSWY3DPEHPK3PXP');
      expect(status.setupUrl, startsWith('otpauth://'));
      // Nothing to write down until the code has proved the app is set up.
      expect(status.recoveryCodes, isEmpty);
    });

    test('a live factor carries the codes, not the secret', () {
      final status = TwoFactorStatus.fromJson({
        'enabled': true,
        'confirming': false,
        'qr_svg': null,
        'setup_key': null,
        'recovery_codes': ['aaaa-bbbb', 'cccc-dddd'],
      });

      expect(status.enabled, isTrue);
      expect(status.confirming, isFalse);
      expect(status.setupKey, isNull);
      expect(status.recoveryCodes, ['aaaa-bbbb', 'cccc-dddd']);
    });

    test('survives a payload missing every field', () {
      final status = TwoFactorStatus.fromJson({});

      expect(status.enabled, isFalse);
      expect(status.confirming, isFalse);
      expect(status.recoveryCodes, isEmpty);
    });

    test('reads recovery codes that arrive as numbers', () {
      final status = TwoFactorStatus.fromJson({
        'enabled': true,
        'recovery_codes': [12345, 'aaaa-bbbb'],
      });

      expect(status.recoveryCodes, ['12345', 'aaaa-bbbb']);
    });
  });
}
