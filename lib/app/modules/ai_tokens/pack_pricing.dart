import '../../data/models/ai_models.dart';

/// A pack priced against the others sold beside it.
///
/// A list of packs is a price list, and a price list is only useful if the
/// reader can tell which line is the better deal. "Rp 250.000 for 1.000.000
/// token" against "Rp 30.000 for 100.000 token" is arithmetic nobody should be
/// doing on a phone, so the rate is worked out here and shown on the card.
class PackValue {
  final AiTokenPack pack;

  /// Rupiah per thousand tokens — the number that makes two packs comparable.
  /// Null when the pack carries no tokens and there is no rate to speak of.
  final double? pricePerThousand;

  /// The best rate on offer. Never set when every pack costs the same per
  /// token: a badge that lands on all of them says nothing.
  final bool isBestValue;

  /// How much cheaper this pack's rate is than the worst rate on offer, as a
  /// percentage. Zero on the worst rate itself, and whenever there is nothing
  /// to compare against.
  final int savingsPercent;

  const PackValue({
    required this.pack,
    this.pricePerThousand,
    this.isBestValue = false,
    this.savingsPercent = 0,
  });

  bool get hasSavings => savingsPercent > 0;
}

/// Price every pack against the rest of the list.
///
/// Order is preserved — the server sorts the packs, and re-ordering them by
/// value would fight whatever the seller arranged.
List<PackValue> rankPacks(List<AiTokenPack> packs) {
  final rates = <int, double>{};

  for (final pack in packs) {
    if (pack.tokenAmount > 0 && pack.price > 0) {
      rates[pack.id] = pack.price / (pack.tokenAmount / 1000);
    }
  }

  if (rates.isEmpty) {
    return packs.map((pack) => PackValue(pack: pack)).toList();
  }

  final best = rates.values.reduce((a, b) => a < b ? a : b);
  final worst = rates.values.reduce((a, b) => a > b ? a : b);

  // Every pack priced alike: there is no better deal to point at.
  final flatPricing = worst - best < 0.01;

  // Ties on the best rate would otherwise all wear the badge; the first one
  // wins it, which is the topmost on screen.
  var bestClaimed = false;

  return packs.map((pack) {
    final rate = rates[pack.id];

    if (rate == null) {
      return PackValue(pack: pack);
    }

    final isBest = !flatPricing && !bestClaimed && rate - best < 0.01;
    if (isBest) {
      bestClaimed = true;
    }

    return PackValue(
      pack: pack,
      pricePerThousand: rate,
      isBestValue: isBest,
      savingsPercent: flatPricing
          ? 0
          : (((worst - rate) / worst) * 100).round(),
    );
  }).toList();
}
