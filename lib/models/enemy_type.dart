import 'package:flutter/material.dart';

/// Behavioural family of a hostile unit.
enum EnemyCategory {
  /// Fast, low health.
  drone,

  /// Slow, high health.
  malware,
}

/// Stable identifiers for enemy archetypes.
enum EnemyType {
  saboteurDrone,
  malwareCrawler,
}

/// Immutable definition of an enemy archetype. Health/speed scale at spawn time
/// via the wave/zone multipliers; these are the base values.
@immutable
class EnemySpec {
  const EnemySpec({
    required this.type,
    required this.name,
    required this.category,
    required this.baseHealth,
    required this.baseSpeed,
    required this.coreDamage,
    required this.mwReward,
    required this.tint,
    this.spriteKey,
    this.radius = 0.28,
  });

  final EnemyType type;
  final String name;
  final EnemyCategory category;

  /// Base hit points before zone/wave scaling.
  final double baseHealth;

  /// Base movement speed in tiles/second before scaling.
  final double baseSpeed;

  /// Integrity removed from the BESS 1M core if this enemy reaches the end.
  final double coreDamage;

  /// MW granted to the player on kill.
  final int mwReward;

  /// Placeholder colour until a real sprite is dropped in.
  final Color tint;

  /// Atlas/sprite key for production art. Null while using placeholder shapes.
  final String? spriteKey;

  /// Visual/collision radius in tile units.
  final double radius;
}
