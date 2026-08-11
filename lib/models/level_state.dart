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
    required this.pvOutput,
    required this.dcDraw,
    required this.dcIncome,
    required this.dcPowered,
    required this.sunFactor,
    required this.isNight,
    required this.bessLevel,
    required this.dcLevel,
    required this.bessUpgradeCost,
    required this.dcUpgradeCost,
    required this.coreIntegrity,
    required this.maxCoreIntegrity,
    required this.waveNumber,
    required this.totalWaves,
    required this.phase,
    required this.elapsedSeconds,
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
  final double pvOutput; // effective (sunlight-scaled) output
  final double dcDraw;
  final double dcIncome;
  final bool dcPowered;

  /// Solar irradiance 0..1 (0 at night) and a convenience night flag.
  final double sunFactor;
  final bool isNight;

  // Facilities.
  final int bessLevel;
  final int dcLevel;
  final int bessUpgradeCost;
  final int dcUpgradeCost;

  // Core / waves.
  final double coreIntegrity;
  final double maxCoreIntegrity;
  final int waveNumber;
  final int totalWaves;
  final RunPhase phase;
  final double elapsedSeconds;
  final bool bossWaveActive;

  double get integrityFraction => maxCoreIntegrity <= 0
      ? 0
      : (coreIntegrity / maxCoreIntegrity).clamp(0, 1);

  double get energyFraction =>
      energyCapacity <= 0 ? 0 : (energy / energyCapacity).clamp(0, 1);

  /// Net energy per second (PV production minus Data Center draw). Negative
  /// means the BESS is draining even before towers fire.
  double get netEnergy => pvOutput - dcDraw;
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
