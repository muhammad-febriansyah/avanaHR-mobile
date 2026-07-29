import 'package:avanahr/app/data/models/ai_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shapes copied from a real `/me/ai/tokens` body, so a renamed field on the
/// Laravel side fails here rather than on somebody's phone.
void main() {
  group('AiTokenBalance', () {
    test('keeps the company allowance and the personal wallet apart', () {
      final balance = AiTokenBalance.fromJson({
        'company_remaining': 1500,
        'personal_balance': 8000,
        'effective_remaining': 9500,
        'user_cap': 1500,
        'user_used': 0,
        'period': 'Juli 2026',
      });

      expect(balance.companyRemaining, 1500);
      expect(balance.personalBalance, 8000);
      // Personal is added to the capped company share, not clamped by it.
      expect(balance.effectiveRemaining, 9500);
    });

    test('reads an uncapped company as null rather than zero', () {
      // Null means "no limit"; zero would mean "nothing left" and read as the
      // opposite on screen.
      final balance = AiTokenBalance.fromJson({
        'company_remaining': null,
        'personal_balance': 0,
        'effective_remaining': null,
        'user_cap': null,
        'user_used': 320,
        'period': 'Juli 2026',
      });

      expect(balance.companyRemaining, isNull);
      expect(balance.effectiveRemaining, isNull);
      expect(balance.userCap, isNull);
      expect(balance.userUsed, 320);
    });

    test('survives a payload missing every field', () {
      final balance = AiTokenBalance.fromJson({});

      expect(balance.personalBalance, 0);
      expect(balance.userUsed, 0);
      expect(balance.period, '');
    });
  });

  group('AiTokenPack', () {
    test('reads a pack on sale', () {
      final pack = AiTokenPack.fromJson({
        'id': 3,
        'name': 'Paket Hemat',
        'token_amount': 50000,
        'price': 25000,
        'description': 'Cukup untuk sebulan',
      });

      expect(pack.id, 3);
      expect(pack.tokenAmount, 50000);
      expect(pack.price, 25000);
      expect(pack.description, 'Cukup untuk sebulan');
    });

    test('treats a missing description as absent, not as text', () {
      expect(
        AiTokenPack.fromJson({
          'id': 1,
          'name': 'Paket',
          'token_amount': 10,
          'price': 5,
        }).description,
        isNull,
      );
    });
  });

  group('AiTokenOrder', () {
    test('only a completed order counts as paid', () {
      const paid = {
        'order_number': 'AIU-1',
        'pack_name': 'Paket Hemat',
        'token_amount': 50000,
        'amount': 25000,
        'status': 'completed',
      };

      expect(AiTokenOrder.fromJson(paid).isPaid, isTrue);
      expect(
        AiTokenOrder.fromJson({...paid, 'status': 'pending'}).isPaid,
        isFalse,
      );
      expect(
        AiTokenOrder.fromJson({...paid, 'status': 'failed'}).isPaid,
        isFalse,
      );
    });

    test('an order with no status is treated as unpaid', () {
      expect(AiTokenOrder.fromJson({'order_number': 'AIU-2'}).isPaid, isFalse);
    });
  });
}
