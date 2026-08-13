import 'package:flutter/material.dart';

import '../models/tower_type.dart';

/// The authoritative catalog of every tower and its upgrade tiers. Rendering
/// reads [TowerSpec.tint]/[TowerSpec.spriteKey] from here, so swapping in real
/// sprites is a data change, not a code change.
class TowerCatalog {
  static const Map<TowerType, TowerSpec> _specs = {
    TowerType.pvPanel: TowerSpec(
      type: TowerType.pvPanel,
      name: 'PV Panel',
      category: TowerCategory.economy,
      tint: Color(0xFF2E7DF6),
      placeableOn: TilePlacement.safeZone,
      tiers: [
        TowerTier(cost: 120, mwPerSecond: 4),
        TowerTier(cost: 360, mwPerSecond: 8),
        TowerTier(cost: 1080, mwPerSecond: 14),
      ],
    ),
    TowerType.windTurbine: TowerSpec(
      type: TowerType.windTurbine,
      name: 'Wind Turbine',
      category: TowerCategory.economy,
      tint: Color(0xFF7FB2C9),
      placeableOn: TilePlacement.safeZone,
      tiers: [
        TowerTier(cost: 160, mwPerSecond: 5),
        TowerTier(cost: 510, mwPerSecond: 10),
        TowerTier(cost: 1500, mwPerSecond: 17),
      ],
    ),
    TowerType.bess: TowerSpec(
      type: TowerType.bess,
      name: 'BESS Unit',
      category: TowerCategory.storage,
      tint: Color(0xFF3A4E6B),
      placeableOn: TilePlacement.safeZone,
      tiers: [
        TowerTier(cost: 180, capacity: 50),
        TowerTier(cost: 540, capacity: 100),
        TowerTier(cost: 1560, capacity: 170),
      ],
    ),
    TowerType.dataCenter: TowerSpec(
      type: TowerType.dataCenter,
      name: 'Data Center',
      category: TowerCategory.datacenter,
      tint: Color(0xFF5B6B85),
      placeableOn: TilePlacement.safeZone,
      tiers: [
        TowerTier(cost: 270, dcPower: 1.0),
        TowerTier(cost: 840, dcPower: 2.0),
        TowerTier(cost: 2400, dcPower: 3.5),
      ],
    ),
    TowerType.droneBay: TowerSpec(
      type: TowerType.droneBay,
      name: 'Drone Bay',
      category: TowerCategory.droneBay,
      tint: Color(0xFF19B36B),
      placeableOn: TilePlacement.any,
      tiers: [
        TowerTier(
            cost: 240, damage: 9, range: 4.5, fireInterval: 0.55,
            energyCost: 1.2, droneCount: 1),
        TowerTier(
            cost: 780, damage: 14, range: 5.5, fireInterval: 0.45,
            energyCost: 1.6, droneCount: 2),
        TowerTier(
            cost: 2280, damage: 20, range: 6.5, fireInterval: 0.38,
            energyCost: 2.0, droneCount: 3),
      ],
    ),
    TowerType.scissorBarrier: TowerSpec(
      type: TowerType.scissorBarrier,
      name: 'Automated Scissor Barrier',
      category: TowerCategory.slow,
      tint: Color(0xFF00C2A8),
      placeableOn: TilePlacement.path,
      tiers: [
        TowerTier(cost: 90, slowMultiplier: 0.5),
        TowerTier(cost: 270, slowMultiplier: 0.36),
        TowerTier(cost: 840, slowMultiplier: 0.24),
      ],
    ),
    TowerType.shockTransformer: TowerSpec(
      type: TowerType.shockTransformer,
      name: '6300A Shock Transformer',
      category: TowerCategory.damage,
      tint: Color(0xFFFF8A1E),
      placeableOn: TilePlacement.safeZone,
      chainThreshold: 3,
      tiers: [
        TowerTier(
            cost: 210,
            damage: 20,
            range: 3.4,
            fireInterval: 0.7,
            chainRadius: 1.6,
            chainBonus: 1.5,
            energyCost: 2.5),
        TowerTier(
            cost: 660,
            damage: 34,
            range: 4.0,
            fireInterval: 0.6,
            chainRadius: 1.9,
            chainBonus: 1.75,
            energyCost: 3.5),
        TowerTier(
            cost: 2040,
            damage: 55,
            range: 4.6,
            fireInterval: 0.5,
            chainRadius: 2.2,
            chainBonus: 2.0,
            energyCost: 5),
      ],
    ),
    TowerType.intelCenter: TowerSpec(
      type: TowerType.intelCenter,
      name: 'Intel Center',
      category: TowerCategory.intel,
      tint: Color(0xFF7A5CF0),
      placeableOn: TilePlacement.safeZone,
      tiers: [
        TowerTier(
            cost: 1800,
            energyCost: 0,
            mwPerSecond: 0,
            upkeep: 2.5,
            dcLoad: 0.8,
            forecastNights: 1),
        TowerTier(
            cost: 4200,
            upkeep: 4.0,
            dcLoad: 1.2,
            forecastNights: 2),
        TowerTier(
            cost: 9000,
            upkeep: 6.5,
            dcLoad: 1.8,
            forecastNights: 4),
      ],
    ),
  };

  static TowerSpec of(TowerType type) => _specs[type]!;

  static List<TowerSpec> get all => _specs.values.toList();

  /// Towers a player can select from the build tray, in display order.
  static const List<TowerType> buildTray = [
    TowerType.pvPanel,
    TowerType.windTurbine,
    TowerType.bess,
    TowerType.dataCenter,
    TowerType.droneBay,
    TowerType.scissorBarrier,
    TowerType.shockTransformer,
    TowerType.intelCenter,
  ];
}
