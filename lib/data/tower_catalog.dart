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
        TowerTier(cost: 40, mwPerSecond: 4),
        TowerTier(cost: 60, mwPerSecond: 8),
        TowerTier(cost: 90, mwPerSecond: 14),
      ],
    ),
    TowerType.windTurbine: TowerSpec(
      type: TowerType.windTurbine,
      name: 'Wind Turbine',
      category: TowerCategory.economy,
      tint: Color(0xFF7FB2C9),
      placeableOn: TilePlacement.safeZone,
      tiers: [
        TowerTier(cost: 55, mwPerSecond: 5),
        TowerTier(cost: 85, mwPerSecond: 10),
        TowerTier(cost: 125, mwPerSecond: 17),
      ],
    ),
    TowerType.scissorBarrier: TowerSpec(
      type: TowerType.scissorBarrier,
      name: 'Automated Scissor Barrier',
      category: TowerCategory.slow,
      tint: Color(0xFF00C2A8),
      placeableOn: TilePlacement.path,
      tiers: [
        TowerTier(cost: 30, slowMultiplier: 0.5),
        TowerTier(cost: 45, slowMultiplier: 0.36),
        TowerTier(cost: 70, slowMultiplier: 0.24),
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
            cost: 70,
            damage: 14,
            range: 2.2,
            fireInterval: 0.9,
            chainRadius: 1.4,
            chainBonus: 1.5,
            energyCost: 2.5),
        TowerTier(
            cost: 110,
            damage: 24,
            range: 2.6,
            fireInterval: 0.8,
            chainRadius: 1.6,
            chainBonus: 1.75,
            energyCost: 3.5),
        TowerTier(
            cost: 170,
            damage: 40,
            range: 3.0,
            fireInterval: 0.7,
            chainRadius: 1.9,
            chainBonus: 2.0,
            energyCost: 5),
      ],
    ),
  };

  static TowerSpec of(TowerType type) => _specs[type]!;

  static List<TowerSpec> get all => _specs.values.toList();

  /// Towers a player can select from the build tray, in display order.
  static const List<TowerType> buildTray = [
    TowerType.pvPanel,
    TowerType.windTurbine,
    TowerType.scissorBarrier,
    TowerType.shockTransformer,
  ];
}
