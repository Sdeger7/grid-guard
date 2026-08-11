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
    if (spec.category == TowerCategory.slow) {
      _renderBarrier(canvas);
    } else {
      _renderTransformer(canvas);
    }
    _drawTierPips(canvas, game.iso.halfH);
  }

  /// Scissor Barrier: two steel posts with a crossed scissor gate between them.
  void _renderBarrier(Canvas canvas) {
    final halfW = game.iso.halfW;
    final halfH = game.iso.halfH;
    final postShades = faceShades(const Color(0xFF3E4A57));

    // Two posts, offset left/right along the tile.
    for (final dx in [-halfW * 0.42, halfW * 0.42]) {
      canvas.save();
      canvas.translate(dx, 0);
      drawIsoBox(
        canvas,
        halfW: halfW,
        halfH: halfH,
        height: halfH * 0.9,
        top: postShades.top,
        left: postShades.left,
        right: postShades.right,
        footScale: 0.16,
      );
      canvas.restore();
    }

    // Scissor blades (an X) spanning the gate, in the tower's teal.
    final blade = Paint()
      ..color = spec.tint
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final y = -halfH * 0.7;
    canvas.drawLine(Offset(-halfW * 0.42, y - 6),
        Offset(halfW * 0.42, y + 4), blade);
    canvas.drawLine(Offset(-halfW * 0.42, y + 4),
        Offset(halfW * 0.42, y - 6), blade);
    // Pivot bolt.
    canvas.drawCircle(Offset(0, y - 1), 2.4,
        Paint()..color = const Color(0xFFEAF6F4));
  }

  /// 6300A Shock Transformer: an orange housing with ceramic insulator stacks
  /// and an emitter node that flares white when it fires.
  void _renderTransformer(Canvas canvas) {
    final halfW = game.iso.halfW;
    final halfH = game.iso.halfH;
    final base = spec.tint;
    final glow = _fireFlash > 0
        ? Color.lerp(base, const Color(0xFFFFF3C0), _fireFlash)!
        : base;
    final s = faceShades(glow);
    final housingH = halfH * (1.2 + 0.35 * tier);

    drawIsoBox(
      canvas,
      halfW: halfW,
      halfH: halfH,
      height: housingH,
      top: s.top,
      left: s.left,
      right: s.right,
      edge: const Color(0x66FFFFFF),
      footScale: 0.6,
    );

    // Cooling fins on the front-right face.
    final fin = Paint()
      ..color = const Color(0x33000000)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final fy = -housingH * (i / 4);
      canvas.drawLine(Offset(halfW * 0.05, fy + halfH * 0.28),
          Offset(halfW * 0.34, fy + halfH * 0.1), fin);
    }

    // Ceramic insulator stacks + emitter on the lid.
    canvas.save();
    canvas.translate(0, -housingH);
    for (final dx in [-halfW * 0.22, halfW * 0.22]) {
      for (var d = 0; d < 3; d++) {
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(dx, -d * 4.0), width: 9 - d.toDouble(), height: 4),
          Paint()..color = const Color(0xFFCBB89A),
        );
      }
    }
    // Emitter node between the insulators.
    final emitter = _fireFlash > 0 ? const Color(0xFFFFFFFF) : const Color(0xFFFFC46B);
    canvas.drawCircle(Offset(0, -8), _fireFlash > 0 ? 5 : 3.5,
        Paint()..color = emitter);
    canvas.restore();
  }

  void _drawTierPips(Canvas canvas, double halfH) {
    final paint = Paint()..color = const Color(0xFFFFE08A);
    for (var i = 0; i <= tier; i++) {
      canvas.drawCircle(Offset(-6 + i * 6.0, -halfH * 2.3), 2.0, paint);
    }
  }
}
