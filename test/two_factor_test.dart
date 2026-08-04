import 'package:avanahr/app/data/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoginResult', () {
    test('a plain sign-in is a session and nothing else to do', () {
      const result = LoginResult.success();

      expect(result.isSuccess, isTrue);
      expect(result.needsTwoFactor, isFalse);
      expect(result.error, isNull);
    });

    test('a challenge is not a success, so the app must not route to main', () {
      const result = LoginResult.twoFactorRequired('abc123');

      expect(result.needsTwoFactor, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.challengeToken, 'abc123');
      expect(result.error, isNull);
    });

    test('a failure asks for neither a session nor a code', () {
      const result = LoginResult.failed('Email atau kata sandi salah.');

      expect(result.isSuccess, isFalse);
      expect(result.needsTwoFactor, isFalse);
      expect(result.error, 'Email atau kata sandi salah.');
    });
  });

  group('TwoFactorResult', () {
    test('a verified code opens the session', () {
      const result = TwoFactorResult.success();

      expect(result.isSuccess, isTrue);
      expect(result.challengeExpired, isFalse);
    });

    test('a wrong code leaves the challenge alive to retry', () {
      const result = TwoFactorResult.failed('Kode verifikasi tidak valid.');

      expect(result.isSuccess, isFalse);
      expect(result.challengeExpired, isFalse);
      expect(result.error, 'Kode verifikasi tidak valid.');
    });

    test('a spent challenge cannot be retried from the code screen', () {
      const result = TwoFactorResult.expired('Sesi verifikasi telah berakhir.');

      expect(result.isSuccess, isFalse);
      expect(result.challengeExpired, isTrue);
      expect(result.error, 'Sesi verifikasi telah berakhir.');
    });
  });
}
