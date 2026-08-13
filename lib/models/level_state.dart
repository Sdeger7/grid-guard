import 'package:flutter/foundation.dart';

import 'star_rating.dart';

/// Where a run currently is in its lifecycle.
enum RunPhase {
  /// Pre-first-wave; player can build freely.
  building,

  /// Waves are spawning / in flight.
  inProgress,

  /// All waves cleared, core alive.
  won,

  /// Core integrity hit zero.
  lost,
}

/// A lightweight, immutable snapshot of the live run, published to the UI a few
/// times per second so the HUD can rebuild without watching every game frame.
///
/// Mirrors the energy-flow economy: [energy]/[energyCapacity] is the BESS,
/// [money] is the build/upgrade currency the Data Center earns, [score] comes
/// from kills. [pvOutput]/[dcDraw]/[dcIncome]/[dcPowered] expose the live grid
/// balance so the HUD can show whether the grid is in surplus or deficit.
@immutable
class LevelState {
  const LevelState({
    required this.levelId,
    required this.energy,
    required this.energyCapacity,
    required this.money,
    required this.score,
    required this.generation,
    required this.dcDraw,
    required this.dcIncome,
    required this.dcPowered,
    required this.dcLoadFraction,
    required this.sunFactor,
    required this.windFactor,
    required this.isNight,
    required this.dataCenterCount,
    required this.workloadIndex,
    required this.security,
    required this.coins,
    required this.damagedCount,
    required this.totalRepairCost,
    required this.threat,
    required this.threatTarget,
    required this.baseValue,
    required this.coreIntegrity,
    required this.maxCoreIntegrity,
    required this.waveNumber,
    required this.dayNumber,
    required this.minutesToRaid,
    required this.forecastRange,
    required this.tonightRaided,
    required this.tonightWeight,
    required this.forecastAccuracy,
    required this.gridPrice,
    required this.gridImporting,
    required this.gridContracts,
    required this.operatingCost,
    required this.lightingLoad,
    required this.averageCondition,
    required this.wornCount,
    required this.reputation,
    required this.firewallName,
    required this.firewallTier,
    required this.vaultMoney,
    required this.vaultWatt,
    required this.netMoneyRate,
    required this.zoneName,
    required this.zoneEmoji,
    required this.sunriseLabel,
    required this.sunsetLabel,
    required this.eventName,
    required this.eventEmoji,
    required this.weatherEmoji,
    required this.weatherName,
    required this.nightWavesTotal,
    required this.nightWavesDone,
    required this.totalWaves,
    required this.phase,
    required this.elapsedSeconds,
    this.endless = false,
    this.bossWaveActive = false,
  });

  final int levelId;

  // Energy (BESS).
  final double energy;
  final double energyCapacity;

  // Currencies / performance.
  final int money;
  final int score;

  // Live grid balance.
  final double generation; // total effective output (solar + wind)
  final double dcDraw;
  final double dcIncome;
  final bool dcPowered;

  /// Share of Data Center demand the grid is meeting, 0..1.
  final double dcLoadFraction;

  /// Solar irradiance 0..1 (0 at night), wind strength 0..1, and a night flag.
  final double sunFactor;
  final double windFactor;
  final bool isNight;

  // Facilities.
  final int dataCenterCount;

  /// Index into DcWorkloadCatalog.workloads — the DC's current job.
  final int workloadIndex;

  /// Current base security rating (gates high-value workloads).
  final int security;

  /// WATT mined this run (crypto workloads only).
  final double coins;

  /// Damaged structures and what it costs to fix them all.
  final int damagedCount;
  final int totalRepairCost;

  /// Live raid pressure and how much the base is worth (drives that pressure).
  final double threat;

  /// Where [threat] is heading under the current contract. Higher than [threat]
  /// means heat is still climbing toward the job the player just accepted.
  final double threatTarget;
  final int baseValue;

  // Core / waves.
  final double coreIntegrity;
  final double maxCoreIntegrity;
  final int waveNumber;

  /// Which day of the run this is. Raids only happen at night, so the day
  /// number is the real progress marker the player counts.
  final int dayNumber;

  /// Minutes until the next scheduled raid window, or -1 when none is coming.
  /// Being present for one is worth far more than any upgrade, so the player
  /// is told when it is.
  final int minutesToRaid;

  /// How many nights ahead the Intel Center can see (0 = no warning at all),
  /// and what it says about tonight.
  final int forecastRange;
  final bool tonightRaided;
  final double tonightWeight;

  /// How often that reading is right, 0..1 — never 1.
  final double forecastAccuracy;

  /// Live grid price per unit of energy, and whether the site is buying.
  final double gridPrice;
  final bool gridImporting;

  /// How many fixed-term power contracts are running.
  final int gridContracts;

  /// MONEY per second the site costs simply to keep running.
  final double operatingCost;

  /// Energy per second the site's own lighting draws after dark.
  final double lightingLoad;

  /// How worn the plant is, and how many units are past 90% of nameplate.
  final double averageCondition;
  final int wornCount;

  /// Cyber posture and standing, and what is banked out of an intruder's reach.
  final double reputation;
  final String firewallName;
  final int firewallTier;
  final double vaultMoney;
  final double vaultWatt;

  /// Net MONEY per second — the direction the balance is actually moving.
  final double netMoneyRate;

  /// Where the site stands.
  final String zoneName;
  final String zoneEmoji;

  /// Real sunrise and sunset for the site's province, today.
  final String sunriseLabel;
  final String sunsetLabel;

  /// This week's world event, or the quiet-week placeholder.
  final String eventName;
  final String eventEmoji;

  /// Today's forecast, for the status strip.
  final String weatherEmoji;
  final String weatherName;

  /// Tonight's wave plan and how much of it has already landed.
  final int nightWavesTotal;
  final int nightWavesDone;
  final int totalWaves;
  final RunPhase phase;
  final double elapsedSeconds;

  /// Endless survival run (waveNumber is the raid count, no total).
  final bool endless;
  final bool bossWaveActive;

  double get integrityFraction => maxCoreIntegrity <= 0
      ? 0
      : (coreIntegrity / maxCoreIntegrity).clamp(0, 1);

  double get energyFraction =>
      energyCapacity <= 0 ? 0 : (energy / energyCapacity).clamp(0, 1);

  /// Net energy per second (total generation minus Data Center draw). Negative
  /// means the BESS is draining even before towers fire.
  /// What the battery is actually gaining or losing: generation less the
  /// machines and less the lights, which are on all night and are not free.
  double get netEnergy => generation - dcDraw - lightingLoad;
}

/// The computed outcome of a finished run, handed to the level-end screen and
/// persisted through [SaveService].
@immutable
class LevelResult {
  const LevelResult({
    required this.levelId,
    required this.stars,
    required this.baseGridCredits,
    required this.finalScore,
    required this.timeSeconds,
    required this.integrityRemaining,
  });

  final int levelId;
  final StarRating stars;

  /// Grid Credits before any 2x rewarded-ad multiplier.
  final int baseGridCredits;
  final int finalScore;
  final double timeSeconds;
  final double integrityRemaining;

  bool get isWin => stars.isWin;
}
