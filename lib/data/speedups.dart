import 'package:flutter/foundation.dart';

/// What a paid item hands the player when it is bought.
enum SpeedupEffect {
  /// Credits a block of production instantly, as if the site had run for that
  /// long unattended.
  bankedHours,

  /// Straight cash into the build fund.
  cash,

  /// Repairs every damaged structure on the site at no cash cost.
  fullRepair,

  /// The season pass: a standing subscription rather than a one-off.
  gridPass,
}

/// A real-money purchase. These exist because the site is deliberately a long
/// project — days of building, not minutes — so the thing worth selling is
/// time, not power. Nothing here is unavailable to a patient player.
///
/// WATT is deliberately absent and must stay that way. It is a closed
/// in-game currency: minted only by mining hardware, spent only on perks, and
/// never bought or sold for real money. That keeps the economy honest and
/// keeps the game clear of the gambling and securities rules that attach the
/// moment a virtual currency has a real-money price.
@immutable
class Speedup {
  const Speedup({
    required this.sku,
    required this.name,
    required this.emoji,
    required this.priceLabel,
    required this.effect,
    required this.amount,
    required this.blurb,
  });

  final String sku;
  final String name;
  final String emoji;

  /// Display price. The store SDK is the source of truth for real pricing;
  /// this is the fallback label.
  final String priceLabel;

  final SpeedupEffect effect;

  /// Hours, cash or WATT, depending on [effect].
  final double amount;

  final String blurb;
}

class SpeedupCatalog {
  static const List<Speedup> items = [
    // The season pass sits first because it is the offer that actually suits
    // this game: a long build rewards a standing relationship, not impulse
    // buys, and everything it grants is time and paint rather than power.
    Speedup(
      sku: 'grid_pass',
      name: 'Grid Pass — season',
      emoji: '🎫',
      priceLabel: '\$4.99 / month',
      effect: SpeedupEffect.gridPass,
      amount: 1,
      blurb: 'Doubles banked offline hours, a daily 4-hour shift on the house, '
          'and the season wardrobe. No stat is touched.',
    ),
    Speedup(
      sku: 'rush_4h',
      name: '4-Hour Shift',
      emoji: '⏩',
      priceLabel: '\$0.99',
      effect: SpeedupEffect.bankedHours,
      amount: 4,
      blurb: 'Instantly bank four hours of production.',
    ),
    Speedup(
      sku: 'rush_24h',
      name: 'Full Day Shift',
      emoji: '⏭️',
      priceLabel: '\$2.99',
      effect: SpeedupEffect.bankedHours,
      amount: 24,
      blurb: 'A whole day of production, credited now.',
    ),
    Speedup(
      sku: 'crew_callout',
      name: 'Emergency Crew',
      emoji: '🚨',
      priceLabel: '\$1.99',
      effect: SpeedupEffect.fullRepair,
      amount: 1,
      blurb: 'Repairs every damaged structure on site, free.',
    ),
    Speedup(
      sku: 'cash_5k',
      name: 'Capital Injection',
      emoji: '💰',
      priceLabel: '\$4.99',
      effect: SpeedupEffect.cash,
      amount: 5000,
      blurb: '+5,000 MONEY straight into the build fund.',
    ),
  ];
}
