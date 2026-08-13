import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Broad behavioural family a tower belongs to. Gameplay systems branch on this
/// rather than on the concrete [TowerType] so new towers slot in cleanly.
enum TowerCategory {
  /// Deals no damage; reshapes/slows enemy flow (e.g. Scissor Barrier).
  slow,

  /// Deals damage, optionally area/chaining (e.g. Shock Transformer).
  damage,

  /// Generates energy (PV Panel, Wind Turbine).
  economy,

  /// Adds battery storage capacity (BESS).
  storage,

  /// Consumes energy to earn money — runs the workload (Data Center).
  datacenter,

  /// Launches friendly interceptor drones that hunt raiders (Drone Bay).
  droneBay,

  /// Buys warning: forecasts which nights get raided and how hard. Expensive to
  /// build, expensive to run, and it borrows compute from the Data Centers.
  intel,
}

/// Stable identifiers for every placeable structure. Kept as an enum so level
/// configs, the store, and save data can reference towers by a compact key.
enum TowerType {
  pvPanel,
  windTurbine,
  bess,
  dataCenter,
  droneBay,
  scissorBarrier,
  shockTransformer,
  intelCenter,
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
    this.capacity = 0,
    this.dcPower = 0,
    this.droneCount = 0,
    this.upkeep = 0,
    this.dcLoad = 0,
    this.forecastNights = 0,
    this.forecastAccuracy = 0,
  });

  /// MW cost to reach this tier (to *build* for tier 0, to *upgrade into* for
  /// higher tiers).
  final int cost;

  /// MONEY burned per second keeping this running (staff, licences, uplink).
  final double upkeep;

  /// Data-Center compute this structure occupies, subtracted from earning
  /// capacity. Intelligence work has to run on something.
  final double dcLoad;

  /// How many nights ahead this can forecast.
  final int forecastNights;

  /// Odds the forecast is right, 0..1. Deliberately never 1: intelligence is
  /// bought, not guaranteed, and a site that trusts a reading blindly should
  /// occasionally get burned for it.
  final double forecastAccuracy;

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

  /// Storage capacity this unit adds to the grid (BESS units).
  final double capacity;

  /// Data-center output multiplier: income/draw = workload × dcPower (DC units).
  final double dcPower;

  /// How many interceptor drones this bay keeps in the air (Drone Bay).
  final int droneCount;
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

  /// Upgrades never run out.
  ///
  /// A finite ladder means a site is finished the moment the last tier is
  /// bought, and money keeps arriving with nothing to buy — which is exactly
  /// how this game ran out of things to do on day two. Past the hand-written
  /// tiers, every further step is generated: cost climbs [costStep]x while
  /// output climbs [statStep]x, so each upgrade is affordable a little later
  /// than the last and the site is never done.
  static const int tierCeiling = 60;
  static const double costStep = 2.2;
  static const double statStep = 1.14;

  int get maxTier => tierCeiling;

  TowerTier tier(int index) {
    final i = index.clamp(0, tierCeiling);
    if (i < tiers.length) return tiers[i];

    final base = tiers.last;
    final n = i - (tiers.length - 1);
    final cost = math.pow(costStep, n).toDouble();
    final stat = math.pow(statStep, n).toDouble();

    return TowerTier(
      cost: (base.cost * cost).round(),
      damage: base.damage * stat,
      range: base.range + n * 0.12,
      fireInterval: base.fireInterval <= 0
          ? 0
          : math.max(0.12, base.fireInterval * math.pow(0.97, n).toDouble()),
      mwPerSecond: base.mwPerSecond * stat,
      // Slow multipliers approach, but never reach, a full stop.
      slowMultiplier: base.slowMultiplier >= 1.0
          ? base.slowMultiplier
          : math.max(0.08, base.slowMultiplier * math.pow(0.94, n).toDouble()),
      chainRadius: base.chainRadius + n * 0.08,
      chainBonus: base.chainBonus + n * 0.05,
      energyCost: base.energyCost * math.pow(1.08, n).toDouble(),
      capacity: base.capacity * stat,
      dcPower: base.dcPower * stat,
      // Squadrons and forecasts have hard ceilings; they are not meant to
      // scale forever the way raw output does.
      droneCount: base.droneCount == 0
          ? 0
          : math.min(6, base.droneCount + n ~/ 3),
      upkeep: base.upkeep * math.pow(1.16, n).toDouble(),
      dcLoad: base.dcLoad * math.pow(1.1, n).toDouble(),
      forecastNights: math.min(6, base.forecastNights + n ~/ 4),
      forecastAccuracy: base.forecastAccuracy <= 0
          ? 0
          : math.min(0.95, base.forecastAccuracy + n * 0.005),
    );
  }
}

/// Which tiles a structure may occupy.
enum TilePlacement { path, safeZone, any }
