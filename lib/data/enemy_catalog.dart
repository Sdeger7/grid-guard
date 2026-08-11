import 'package:flutter/material.dart';

import '../models/enemy_type.dart';

/// Authoritative catalog of enemy archetypes. As with towers, rendering reads
/// [EnemySpec.tint]/[EnemySpec.spriteKey] from here so art swaps are data-only.
class EnemyCatalog {
  static const Map<EnemyType, EnemySpec> _specs = {
    EnemyType.saboteurDrone: EnemySpec(
      type: EnemyType.saboteurDrone,
      name: 'Saboteur Drone',
      category: EnemyCategory.drone,
      baseHealth: 26,
      baseSpeed: 1.9,
      coreDamage: 6,
      scoreValue: 10,
      radius: 0.24,
      tint: Color(0xFFE23D4B),
    ),
    EnemyType.malwareCrawler: EnemySpec(
      type: EnemyType.malwareCrawler,
      name: 'Malware Crawler',
      category: EnemyCategory.malware,
      baseHealth: 115,
      baseSpeed: 0.85,
      coreDamage: 16,
      scoreValue: 30,
      radius: 0.34,
      tint: Color(0xFF9B3DE2),
    ),
  };

  static EnemySpec of(EnemyType type) => _specs[type]!;
  static List<EnemySpec> get all => _specs.values.toList();
}
