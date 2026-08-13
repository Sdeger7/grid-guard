import 'package:flutter/foundation.dart';

/// What a paid item hands the player when it is bought.
enum SpeedupEffect {
  /// Credits a block of production instantly, as if the site had run for that
  /// long unattended.
  bankedHours,

  /// Straight cash into the build fund.
  cash,

  /// WATT credited directly, for players who would rather buy than mine.
  watt,

  /// Repairs every damaged structure on the site at no cash cost.
  fullRepair,
}

/// A real-money purchase. These exist because the site is deliberately a long
/// project — days of building, not minutes — so the thing worth selling is
/// time, not power. Nothing here is unavailable to a patient player.
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
      blurb: '+\$5,000 straight into the build fund.',
    ),
    Speedup(
      sku: 'watt_250',
      name: 'WATT Bundle',
      emoji: '⚡',
      priceLabel: '\$9.99',
      effect: SpeedupEffect.watt,
      amount: 250,
      blurb: '250 WATT, for perks you would rather not wait to mine.',
    ),
  ];
}
