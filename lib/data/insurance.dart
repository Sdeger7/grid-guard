import 'package:flutter/foundation.dart';

/// What a policy covers.
enum CoverKind { raid, breach, breakdown }

/// An insurance policy, sold as a real-money subscription.
///
/// A policy never prevents anything: raids still land, breaches still happen,
/// plant still fails. It refunds part of what the loss cost, above an excess
/// the holder carries themselves — so the site still has to be built well and
/// defended, and a policy is a cushion rather than a shield.
///
/// Policies are inert inside a weekly challenge, like everything else that is
/// bought. The compared lane stays free of purchases.
@immutable
class Policy {
  const Policy({
    required this.id,
    required this.sku,
    required this.name,
    required this.emoji,
    required this.covers,
    required this.priceLabel,
    required this.excess,
    required this.payoutShare,
    required this.blurb,
  });

  final String id;
  final String name;
  final String emoji;
  final CoverKind covers;

  /// Store product id, and the price shown when the store has not answered.
  final String sku;
  final String priceLabel;

  /// The first slice of any loss you carry yourself.
  final int excess;

  /// Share of the loss above the excess that is paid out, 0..1.
  final double payoutShare;

  final String blurb;
}

class InsuranceCatalog {
  static const List<Policy> policies = [
    Policy(
      id: 'raid_basic',
      sku: 'policy_raid_basic',
      name: 'Equipment cover',
      emoji: '🛡️',
      covers: CoverKind.raid,
      priceLabel: '\$1.99 / month',
      excess: 400,
      payoutShare: 0.6,
      blurb: 'Pays toward rebuilding what a raid destroys, above the excess.',
    ),
    Policy(
      id: 'raid_full',
      sku: 'policy_raid_full',
      name: 'Equipment cover — full',
      emoji: '🛡️',
      covers: CoverKind.raid,
      priceLabel: '\$3.99 / month',
      excess: 150,
      payoutShare: 0.9,
      blurb: 'Almost all of it, almost immediately. Priced accordingly.',
    ),
    Policy(
      id: 'cyber_basic',
      sku: 'policy_cyber_basic',
      name: 'Cyber liability',
      emoji: '🔐',
      covers: CoverKind.breach,
      priceLabel: '\$2.49 / month',
      excess: 800,
      payoutShare: 0.55,
      blurb: 'Covers part of what a breach costs you — the fine included.',
    ),
    Policy(
      id: 'cyber_full',
      sku: 'policy_cyber_full',
      name: 'Cyber liability — full',
      emoji: '🔐',
      covers: CoverKind.breach,
      priceLabel: '\$4.99 / month',
      excess: 250,
      payoutShare: 0.85,
      blurb: 'For a site holding data it genuinely cannot afford to lose.',
    ),
    Policy(
      id: 'breakdown',
      sku: 'policy_breakdown',
      name: 'Plant breakdown',
      emoji: '🔧',
      covers: CoverKind.breakdown,
      priceLabel: '\$1.99 / month',
      excess: 300,
      payoutShare: 0.7,
      blurb: 'Inverter failures, bearing seizures, and everything else that '
          'simply wears out.',
    ),
  ];

  static Policy byId(String id) =>
      policies.firstWhere((p) => p.id == id, orElse: () => policies.first);

  /// The policies a player currently holds, from whatever the store says they
  /// have bought.
  static Set<String> heldFrom(bool Function(String sku) purchased) {
    final held = <String>{};
    for (final p in policies) {
      if (purchased(p.sku)) held.add(p.id);
    }
    return held;
  }

  /// What is paid on a loss of [loss] under whichever held policy covers it.
  static int payoutFor({
    required Set<String> held,
    required CoverKind kind,
    required int loss,
  }) {
    var best = 0;
    for (final id in held) {
      final p = byId(id);
      if (p.covers != kind) continue;
      final above = loss - p.excess;
      if (above <= 0) continue;
      final paid = (above * p.payoutShare).round();
      if (paid > best) best = paid;
    }
    return best;
  }
}
