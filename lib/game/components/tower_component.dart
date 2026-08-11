import 'dart:ui';

import 'package:flame/components.dart';

import '../../models/level_config.dart';
import '../../models/tower_type.dart';
import 'enemy_component.dart';
import 'iso_box.dart';
import 'iso_component.dart';

/// A placed defensive structure. One component covers both families:
///  - [TowerCategory.slow] (Scissor Barrier): deals no damage; the game reads
///    its tier's `slowMultiplier` when enemies cross its tile.
///  - [TowerCategory.damage] (Shock Transformer): targets and fires a chaining
///    arc, with a bonus when [chainThreshold]+ enemies are clustered.
class TowerComponent extends IsoComponent {
  TowerComponent({
    required this.spec,
    required this.coord,
    this.tier = 0,
  }) : super(
          tile: Vector2(coord.col.toDouble(), coord.row.toDouble()),
          depthBias: 0.2,
        );

  final TowerSpec spec;
  final TileCoord coord;
  int tier;

  double _cooldown = 0;
  double _fireFlash = 0;

  TowerTier get currentTier => spec.tier(tier);
  bool get canUpgrade => tier < spec.maxTier;

  /// MW cost to upgrade to the next tier, or null if maxed.
  int? get upgradeCost => canUpgrade ? spec.tier(tier + 1).cost : null;

  void upgrade() {
    if (canUpgrade) tier++;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_fireFlash > 0) _fireFlash = (_fireFlash - dt).clamp(0, 1);
    if (spec.category != TowerCategory.damage) return;

    _cooldown -= dt;
    if (_cooldown > 0) return;
    _tryFire();
  }

  void _tryFire() {
    final t = currentTier;
    final target = _pickTarget(t.range);
    if (target == null) return;

    // Cluster near the target decides the chain bonus.
    final cluster = <EnemyComponent>[];
    for (final e in game.enemies) {
      if (e.isDead) continue;
      if ((e.tile - target.tile).length <= t.chainRadius) cluster.add(e);
    }
    final chained = cluster.length >= spec.chainThreshold;
    final dmg = chained ? t.damage * t.chainBonus : t.damage;

    // Primary hit.
    target.takeDamage(dmg);
    game.spawnArc(tile.clone(), target.tile.clone(), primary: true);

    // Chain hits fan out from the target.
    if (chained) {
      for (final e in cluster) {
        if (identical(e, target) || e.isDead) continue;
        e.takeDamage(dmg * 0.6);
        game.spawnArc(target.tile.clone(), e.tile.clone(), primary: false);
      }
      game.onChainHit();
    }

    _fireFlash = 0.12;
    _cooldown = t.fireInterval;
    game.onTowerFired();
  }

  /// Targets the enemy furthest along the path (closest to the core) within
  /// range — so the barrier bottleneck feeds this tower a line to chew through.
  EnemyComponent? _pickTarget(double range) {
    EnemyComponent? best;
    double bestProgress = -1;
    for (final e in game.enemies) {
      if (e.isDead) continue;
      if ((e.tile - tile).length > range) continue;
      if (e.pathDistance > bestProgress) {
        bestProgress = e.pathDistance;
        best = e;
      }
    }
    return best;
  }

  @override
  void render(Canvas canvas) {
    final halfW = game.iso.halfW;
    final halfH = game.iso.halfH;
    final base = spec.tint;
    final shades = faceShades(base);

    if (spec.category == TowerCategory.slow) {
      // Barrier: a low, wide unit with a visible gate gap.
      drawIsoBox(
        canvas,
        halfW: halfW,
        halfH: halfH,
        height: halfH * 0.7,
        top: shades.top,
        left: shades.left,
        right: shades.right,
        edge: const Color(0xFFFFFFFF),
        footScale: 0.85,
      );
    } else {
      // Shock Transformer: taller, flashes on fire.
      final glow = _fireFlash > 0
          ? Color.lerp(base, const Color(0xFFFFF3C0), _fireFlash)!
          : base;
      final s = faceShades(glow);
      drawIsoBox(
        canvas,
        halfW: halfW,
        halfH: halfH,
        height: halfH * (1.4 + 0.4 * tier),
        top: s.top,
        left: s.left,
        right: s.right,
        edge: const Color(0xFFFFFFFF),
        footScale: 0.6,
      );
    }

    _drawTierPips(canvas, halfH);
  }

  void _drawTierPips(Canvas canvas, double halfH) {
    final paint = Paint()..color = const Color(0xFFFFFFFF);
    for (var i = 0; i <= tier; i++) {
      canvas.drawCircle(Offset(-6 + i * 6.0, -halfH * 2.0), 2.0, paint);
    }
  }
}
