import 'package:flutter/foundation.dart';

/// A premium package bought with WATT — the currency crypto-mining workloads
/// mint. Packages are permanent account perks that carry into every future run.
///
/// Prices are in whole WATT, and WATT accrues at hundredths per hour, so these
/// are measured in days of mining rather than minutes. That is the point: the
/// perks are the long game.
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
    this.gridExportRate = 0.0,
    this.chargeRateBonus = 0.0,
    this.miningBonus = 0.0,
    this.offlineHoursBonus = 0,
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

  /// How much of the market export price the site actually collects. The
  /// utility connection is the big one: it turns a well-built site into a
  /// second income stream priced by the market, not by a fixed rate.
  final double gridExportRate;

  /// Extra battery charge per second, independent of sun and wind.
  final double chargeRateBonus;

  /// Added to the crypto-mining rate — the only WATT multiplier there is.
  final double miningBonus;

  /// Extra hours of banked offline production.
  final int offlineHoursBonus;
}

class PremiumCatalog {
  static const List<PremiumPackage> packages = [
    PremiumPackage(
      id: 'seed_capital',
      name: 'Seed Capital',
      emoji: '💼',
      price: 1,
      blurb: 'Start every run with +150 build money.',
      startMoneyBonus: 150,
    ),
    PremiumPackage(
      id: 'charged_start',
      name: 'Charged Start',
      emoji: '🔌',
      price: 2,
      blurb: 'Begin fully charged, +60 stored energy.',
      startEnergyBonus: 60,
    ),
    PremiumPackage(
      id: 'grid_expansion',
      name: 'Grid Expansion',
      emoji: '🔋',
      price: 3,
      blurb: '+80 permanent battery capacity.',
      capacityBonus: 80,
    ),
    PremiumPackage(
      id: 'service_contract',
      name: 'Service Contract',
      emoji: '🛠️',
      price: 4,
      blurb: 'All repairs cost 40% less, forever.',
      repairDiscount: 0.4,
    ),
    PremiumPackage(
      id: 'hardened_core',
      name: 'Hardened Core',
      emoji: '🛡️',
      price: 6,
      blurb: '+80 base integrity every run.',
      startCoreBonus: 80,
    ),
    PremiumPackage(
      id: 'trading_desk',
      name: 'Trading Desk',
      emoji: '📈',
      price: 9,
      blurb: 'Data Centers earn 25% more money.',
      incomeMultiplier: 1.25,
    ),
    PremiumPackage(
      id: 'night_shift',
      name: 'Night Shift Crew',
      emoji: '🌙',
      price: 12,
      blurb: 'Banked offline production runs for 16 hours instead of 8.',
      offlineHoursBonus: 8,
    ),
    PremiumPackage(
      id: 'asic_farm',
      name: 'ASIC Farm',
      emoji: '🧮',
      price: 18,
      blurb: 'Crypto Mining mints 50% more WATT.',
      miningBonus: 0.5,
    ),
    PremiumPackage(
      id: 'diesel_backup',
      name: 'Diesel Backup',
      emoji: '🛢️',
      price: 25,
      blurb: 'A generator trickles +4 energy/s day and night.',
      chargeRateBonus: 4,
    ),
    PremiumPackage(
      id: 'grid_connection',
      name: 'Utility Interconnect',
      emoji: '🏗️',
      price: 40,
      blurb: 'Sell surplus power into the market at the live price. The site '
          'stops being an island.',
      gridExportRate: 0.8,
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
    var export = 0.0;
    var charge = 0.0;
    var mining = 0.0;
    var offline = 0;
    for (final p in packages) {
      if (!owned.contains(p.id)) continue;
      export += p.gridExportRate;
      charge += p.chargeRateBonus;
      mining += p.miningBonus;
      offline += p.offlineHoursBonus;
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
      gridExportRate: export,
      chargeRateBonus: charge,
      miningBonus: mining,
      offlineHoursBonus: offline,
    );
  }
}
