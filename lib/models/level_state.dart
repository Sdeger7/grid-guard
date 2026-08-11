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
/// The authoritative fast-changing values (exact MW, exact integrity) live in
/// the Flame game; this is the throttled view of them.
@immutable
class LevelState {
  const LevelState({
    required this.levelId,
    required this.mw,
    required this.coreIntegrity,
    required this.maxCoreIntegrity,
    required this.waveNumber,
    required this.totalWaves,
    required this.phase,
    required this.elapsedSeconds,
    required this.score,
    this.bossWaveActive = false,
  });

  final int levelId;
  final int mw;
  final double coreIntegrity;
  final double maxCoreIntegrity;

  /// 1-based wave index; 0 while still in the building phase.
  final int waveNumber;
  final int totalWaves;
  final RunPhase phase;
  final double elapsedSeconds;
  final int score;
  final bool bossWaveActive;

  double get integrityFraction =>
      maxCoreIntegrity <= 0 ? 0 : (coreIntegrity / maxCoreIntegrity).clamp(0, 1);

  factory LevelState.initial(int levelId, int startingMw, double integrity,
          int totalWaves) =>
      LevelState(
        levelId: levelId,
        mw: startingMw,
        coreIntegrity: integrity,
        maxCoreIntegrity: integrity,
        waveNumber: 0,
        totalWaves: totalWaves,
        phase: RunPhase.building,
        elapsedSeconds: 0,
        score: 0,
      );

  LevelState copyWith({
    int? mw,
    double? coreIntegrity,
    int? waveNumber,
    RunPhase? phase,
    double? elapsedSeconds,
    int? score,
    bool? bossWaveActive,
  }) {
    return LevelState(
      levelId: levelId,
      mw: mw ?? this.mw,
      coreIntegrity: coreIntegrity ?? this.coreIntegrity,
      maxCoreIntegrity: maxCoreIntegrity,
      waveNumber: waveNumber ?? this.waveNumber,
      totalWaves: totalWaves,
      phase: phase ?? this.phase,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      score: score ?? this.score,
      bossWaveActive: bossWaveActive ?? this.bossWaveActive,
    );
  }
}

/// The computed outcome of a finished run, handed to the level-end screen and
/// persisted through [SaveService].
@immutable
class LevelResult {
  const LevelResult({
    required this.levelId,
    required this.stars,
    required this.baseGridCredits,
    required this.mwEarned,
    required this.timeSeconds,
    required this.integrityRemaining,
  });

  final int levelId;
  final StarRating stars;

  /// Grid Credits before any 2x rewarded-ad multiplier.
  final int baseGridCredits;
  final int mwEarned;
  final double timeSeconds;
  final double integrityRemaining;

  bool get isWin => stars.isWin;
}
