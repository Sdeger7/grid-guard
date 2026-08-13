import 'package:flutter/foundation.dart';

/// Firewall tiers.
///
/// Drones come for the hardware; intruders come for the money and the data,
/// and no amount of transformers stops them. Security is bought and upgraded
/// like everything else, it costs money to run, and it is never perfect —
/// a site with the best firewall on the map still loses one attempt in twenty.
@immutable
class FirewallTier {
  const FirewallTier({
    required this.name,
    required this.cost,
    required this.upkeep,
    required this.resistance,
    required this.blurb,
  });

  final String name;
  final int cost;

  /// MONEY per second to keep licensed and patched.
  final double upkeep;

  /// Chance an intrusion is stopped outright, 0..1.
  final double resistance;

  final String blurb;
}

class FirewallCatalog {
  static const List<FirewallTier> tiers = [
    FirewallTier(
      name: 'None',
      cost: 0,
      upkeep: 0,
      resistance: 0.0,
      blurb: 'A default password and hope. Anyone who looks will get in.',
    ),
    FirewallTier(
      name: 'Basic filtering',
      cost: 900,
      upkeep: 0.4,
      resistance: 0.35,
      blurb: 'Off-the-shelf edge filtering. Stops the automated sweeps.',
    ),
    FirewallTier(
      name: 'Managed firewall',
      cost: 3200,
      upkeep: 1.1,
      resistance: 0.55,
      blurb: 'Rules maintained by somebody whose job it is.',
    ),
    FirewallTier(
      name: 'Intrusion detection',
      cost: 9000,
      upkeep: 2.4,
      resistance: 0.70,
      blurb: 'Watches traffic for the shape of an attack, not just its address.',
    ),
    FirewallTier(
      name: 'Segmented network',
      cost: 24000,
      upkeep: 4.5,
      resistance: 0.82,
      blurb: 'A breach in one machine no longer means a breach in all of them.',
    ),
    FirewallTier(
      name: 'Zero trust',
      cost: 60000,
      upkeep: 8.0,
      resistance: 0.90,
      blurb: 'Nothing inside is trusted either. Expensive, and worth it.',
    ),
    FirewallTier(
      name: 'Air-gapped vault',
      cost: 150000,
      upkeep: 14.0,
      resistance: 0.95,
      blurb: 'The best there is, and still not certain. Nothing ever is.',
    ),
  ];

  static FirewallTier at(int index) => tiers[index.clamp(0, tiers.length - 1)];
  static bool canUpgrade(int index) => index < tiers.length - 1;
}

/// What an intrusion did.
enum BreachKind {
  /// Cash siphoned out of the operating account.
  theft,

  /// WATT taken from the balance the site holds.
  wattTheft,

  /// Client data taken. The expensive one: a fine, and a reputation you spend
  /// months rebuilding.
  dataTheft,

  /// Stopped at the edge.
  repelled,
}

/// The site's standing with the people who hand out contracts.
///
/// Reputation is what a data centre actually sells. Lose client records and the
/// good contracts stop being offered at any security rating — you are left
/// hosting cheap traffic until you have earned back the trust, which is exactly
/// what happens to a real operator after a breach.
class Reputation {
  /// Everyone starts trusted.
  static const double initial = 75;
  static const double max = 100;
  static const double min = 5;

  /// What a breach costs, by kind.
  static double penaltyFor(BreachKind kind) {
    switch (kind) {
      case BreachKind.dataTheft:
        return 22;
      case BreachKind.theft:
      case BreachKind.wattTheft:
        return 6;
      case BreachKind.repelled:
        return 0;
    }
  }

  /// Trust rebuilds slowly, per day, and only while nothing goes wrong.
  static const double recoveryPerDay = 1.5;

  /// What contracts pay at a given standing. A trusted operator is offered
  /// better rates on the same work; a suspect one is not offered it at all.
  static double rateMultiplier(double reputation) =>
      (0.55 + (reputation / max) * 0.65).clamp(0.55, 1.2);

  /// The minimum standing a workload's clients will accept.
  static double requiredFor(int workloadIndex) {
    switch (workloadIndex) {
      case 4: // Gov Secrets
        return 80;
      case 3: // Bank Records
        return 65;
      case 2: // Crypto Mining
        return 30;
      default:
        return 0;
    }
  }

  static String bandFor(double reputation) {
    if (reputation >= 85) return 'TRUSTED';
    if (reputation >= 65) return 'SOLID';
    if (reputation >= 40) return 'WATCHED';
    return 'SUSPECT';
  }
}
