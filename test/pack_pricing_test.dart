import 'package:avanahr/app/data/models/ai_models.dart';
import 'package:avanahr/app/modules/ai_tokens/pack_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

AiTokenPack pack(int id, int tokens, int price) =>
    AiTokenPack(id: id, name: 'Paket $id', tokenAmount: tokens, price: price);

/// The buy tab shows a rate per thousand tokens and marks the best deal, so a
/// reader is not left dividing prices by token counts on a phone.
void main() {
  group('rankPacks', () {
    test('rates each pack per thousand tokens', () {
      final ranked = rankPacks([
        pack(1, 100000, 30000), // Rp 300 / 1.000
        pack(2, 1000000, 250000), // Rp 250 / 1.000
      ]);

      expect(ranked[0].pricePerThousand, closeTo(300, 0.001));
      expect(ranked[1].pricePerThousand, closeTo(250, 0.001));
    });

    test('marks the cheapest rate, not the cheapest price', () {
      final ranked = rankPacks([
        pack(1, 100000, 30000), // cheapest to buy, worst rate
        pack(2, 1000000, 250000), // costs most, best rate
      ]);

      expect(ranked[0].isBestValue, isFalse);
      expect(ranked[1].isBestValue, isTrue);
    });

    test('measures savings against the worst rate on offer', () {
      final ranked = rankPacks([
        pack(1, 100000, 30000),
        pack(2, 1000000, 250000),
      ]);

      expect(ranked[0].savingsPercent, 0);
      expect(ranked[0].hasSavings, isFalse);
      // Rp 250 against Rp 300 per thousand.
      expect(ranked[1].savingsPercent, 17);
    });

    test('keeps the seller ordering', () {
      final ranked = rankPacks([
        pack(7, 1000000, 250000),
        pack(3, 100000, 30000),
      ]);

      expect(ranked.map((v) => v.pack.id), [7, 3]);
    });

    test('badges nothing when every pack costs the same per token', () {
      final ranked = rankPacks([
        pack(1, 100000, 25000),
        pack(2, 400000, 100000),
      ]);

      expect(ranked.every((v) => !v.isBestValue), isTrue);
      expect(ranked.every((v) => v.savingsPercent == 0), isTrue);
      // The rate still shows — it is what makes them comparable at all.
      expect(ranked.first.pricePerThousand, closeTo(250, 0.001));
    });

    test('awards a tie on the best rate to the pack listed first', () {
      final ranked = rankPacks([
        pack(1, 100000, 30000), // worst rate
        pack(2, 400000, 100000), // best rate
        pack(3, 800000, 200000), // same best rate
      ]);

      expect(ranked[1].isBestValue, isTrue);
      expect(ranked[2].isBestValue, isFalse);
      expect(ranked[2].savingsPercent, ranked[1].savingsPercent);
    });

    test('leaves a pack with no tokens or no price unrated', () {
      final ranked = rankPacks([pack(1, 0, 30000), pack(2, 500000, 0)]);

      expect(ranked.every((v) => v.pricePerThousand == null), isTrue);
      expect(ranked.every((v) => !v.isBestValue), isTrue);
    });

    test('rates a lone pack without calling it a bargain', () {
      final ranked = rankPacks([pack(1, 500000, 100000)]);

      expect(ranked.single.pricePerThousand, closeTo(200, 0.001));
      // Nothing to be cheaper than.
      expect(ranked.single.isBestValue, isFalse);
      expect(ranked.single.savingsPercent, 0);
    });

    test('survives an empty price list', () {
      expect(rankPacks([]), isEmpty);
    });
  });
}
