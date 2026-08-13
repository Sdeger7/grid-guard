import 'package:flutter/foundation.dart';

/// A premium package bought with WATT — the currency crypto-mining workloads
/// mint. Packages are permanent account perks that carry into every future run,
/// so mining time converts into a real head start.
@immutable
class PremiumPackage {
  const PremiumPackage({
    required this.id,
    required this.name,
    required this.emoji,
    required this.price,
    required this.blurb,
    this.startMoneyBonus = 0,
    this.startEnergyBonus = 0,
    this.capacityBonus = 0,
    this.incomeMultiplier = 1.0,
    this.repairDiscount = 0.0,
    this.startCoreBonus = 0,
  });

  final String id;
  final String name;
  final String emoji;

  /// Cost in WATT.
  final int price;
  final String blurb;

  /// Perks applied at the start of (or throughout) every run.
  final int startMoneyBonus;
  final double startEnergyBonus;
  final double capacityBonus;
  final double incomeMultiplier;

  /// Fraction knocked off repair bills, 0..1.
  final double repairDiscount;
  final double startCoreBonus;
}

class PremiumCatalog {
  static const List<PremiumPackage> packages = [
    PremiumPackage(
      id: 'seed_capital',
      name: 'Seed Capital',
      emoji: '💼',
      price: 40,
      blurb: 'Start every run with +150 build money.',
      startMoneyBonus: 150,
    ),
    PremiumPackage(
      id: 'charged_start',
      name: 'Charged Start',
      emoji: '🔌',
      price: 60,
      blurb: 'Begin fully charged, +60 stored energy.',
      startEnergyBonus: 60,
    ),
    PremiumPackage(
      id: 'grid_expansion',
      name: 'Grid Expansion',
      emoji: '🔋',
      price: 90,
      blurb: '+80 permanent battery capacity.',
      capacityBonus: 80,
    ),
    PremiumPackage(
      id: 'service_contract',
      name: 'Service Contract',
      emoji: '🛠️',
      price: 110,
      blurb: 'All repairs cost 40% less, forever.',
      repairDiscount: 0.4,
    ),
    PremiumPackage(
      id: 'hardened_core',
      name: 'Hardened Core',
      emoji: '🛡️',
      price: 140,
      blurb: '+80 base integrity every run.',
      startCoreBonus: 80,
    ),
    PremiumPackage(
      id: 'trading_desk',
      name: 'Trading Desk',
      emoji: '📈',
      price: 200,
      blurb: 'Data Centers earn 25% more money.',
      incomeMultiplier: 1.25,
    ),
  ];

  static PremiumPackage byId(String id) =>
      packages.firstWhere((p) => p.id == id);

  /// Combined effect of everything the player owns.
  static PremiumPackage effectiveOf(Set<String> owned) {
    var money = 0;
    var energy = 0.0;
    var capacity = 0.0;
    var income = 1.0;
    var repair = 0.0;
    var core = 0.0;
    for (final p in packages) {
      if (!owned.contains(p.id)) continue;
      money += p.startMoneyBonus;
      energy += p.startEnergyBonus;
      capacity += p.capacityBonus;
      income *= p.incomeMultiplier;
      repair = repair + p.repairDiscount;
      core += p.startCoreBonus;
    }
    return PremiumPackage(
      id: '_effective',
      name: 'Owned perks',
      emoji: '⭐',
      price: 0,
      blurb: '',
      startMoneyBonus: money,
      startEnergyBonus: energy,
      capacityBonus: capacity,
      incomeMultiplier: income,
      repairDiscount: repair.clamp(0.0, 0.7),
      startCoreBonus: core,
    );
  }
}
