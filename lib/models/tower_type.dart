import 'package:flutter/material.dart';

/// Broad behavioural family a tower belongs to. Gameplay systems branch on this
/// rather than on the concrete [TowerType] so new towers slot in cleanly.
enum TowerCategory {
  /// Deals no damage; reshapes/slows enemy flow (e.g. Scissor Barrier).
  slow,

  /// Deals damage, optionally area/chaining (e.g. Shock Transformer).
  damage,

  /// Generates MW income (PV Panel).
  economy,
}

/// Stable identifiers for every placeable structure. Kept as an enum so level
/// configs, the store, and save data can reference towers by a compact key.
enum TowerType {
  pvPanel,
  scissorBarrier,
  shockTransformer,
}

/// Immutable per-tier stat block. A [TowerSpec] carries one entry per upgrade
/// tier; index 0 is the base build.
@immutable
class TowerTier {
  const TowerTier({
    required this.cost,
    this.damage = 0,
    this.range = 0,
    this.fireInterval = 0,
    this.mwPerSecond = 0,
    this.slowMultiplier = 1.0,
    this.chainRadius = 0,
    this.chainBonus = 1.0,
    this.energyCost = 0,
  });

  /// MW cost to reach this tier (to *build* for tier 0, to *upgrade into* for
  /// higher tiers).
  final int cost;

  /// Damage per shot (damage towers).
  final double damage;

  /// Effective range in tiles.
  final double range;

  /// Seconds between shots (damage towers). 0 == never fires.
  final double fireInterval;

  /// MW generated per second (economy towers).
  final double mwPerSecond;

  /// Speed multiplier applied to enemies passing this tile (slow towers).
  /// 1.0 == no change, 0.5 == half speed.
  final double slowMultiplier;

  /// Radius within which grouped enemies count toward a chain hit.
  final double chainRadius;

  /// Damage multiplier applied when [chainThreshold]+ enemies are clustered.
  final double chainBonus;

  /// Energy drawn from the BESS per shot (damage towers). No energy → no shot.
  final double energyCost;
}

/// Full, immutable definition of a tower: its identity, family, visual key and
/// ordered upgrade tiers. Rendering reads [spriteKey]/[tint] so real sprites can
/// replace placeholder shapes without touching logic.
@immutable
class TowerSpec {
  const TowerSpec({
    required this.type,
    required this.name,
    required this.category,
    required this.tiers,
    required this.tint,
    this.spriteKey,
    this.placeableOn = TilePlacement.path,
    this.chainThreshold = 3,
  });

  final TowerType type;
  final String name;
  final TowerCategory category;
  final List<TowerTier> tiers;

  /// Placeholder colour used until a real sprite is dropped in.
  final Color tint;

  /// Atlas/sprite key for production art. Null while using placeholder shapes.
  final String? spriteKey;

  /// Where this tower may be placed.
  final TilePlacement placeableOn;

  /// Minimum clustered enemies for a chain bonus to apply (damage towers).
  final int chainThreshold;

  int get maxTier => tiers.length - 1;

  TowerTier tier(int index) => tiers[index.clamp(0, maxTier)];
}

/// Which tiles a structure may occupy.
enum TilePlacement { path, safeZone, any }
