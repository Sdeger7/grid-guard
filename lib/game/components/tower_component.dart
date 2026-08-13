import 'dart:ui';

import '../../models/tower_type.dart';
import 'enemy_component.dart';
import 'iso_box.dart';
import 'structure_component.dart';

/// A placed defensive structure. One component covers both families:
///  - [TowerCategory.slow] (Scissor Barrier): deals no damage; the game reads
///    its tier's `slowMultiplier` when enemies cross its tile.
///  - [TowerCategory.damage] (Shock Transformer): targets and fires a chaining
///    arc, with a bonus when [chainThreshold]+ enemies are clustered.
class TowerComponent extends StructureComponent {
  TowerComponent({
    required super.spec,
    required super.coord,
    super.tier,
  }) : super(depthBias: 0.2);

  double _cooldown = 0;
  double _fireFlash = 0;
  bool _starved = false;

  @override
  void update(double dt) {
    super.update(dt);
    if (_fireFlash > 0) _fireFlash = (_fireFlash - dt).clamp(0, 1);
    if (spec.category != TowerCategory.damage) return;
    // Knocked-out towers can't fire until repaired.
    if (isOffline) return;

    _cooldown -= dt;
    if (_cooldown > 0) return;
    _tryFire();
  }

  void _tryFire() {
    final t = currentTier;
    final target = _pickTarget(t.range);
    if (target == null) return;

    // Draw energy from the BESS to fire. If the grid is starved, the shot is
    // skipped (cooldown not reset, so it fires the instant power returns).
    // Overcharge doubles the punch and doubles what the shot costs.
    final boost = game.overchargeFactor;
    if (!game.tryDrawEnergy(t.energyCost * boost)) {
      _starved = true;
      return;
    }
    _starved = false;

    // Cluster near the target decides the chain bonus.
    final cluster = <EnemyComponent>[];
    for (final e in game.enemies) {
      if (e.isDead) continue;
      if ((e.tile - target.tile).length <= t.chainRadius) cluster.add(e);
    }
    final chained = cluster.length >= spec.chainThreshold;
    final dmg = (chained ? t.damage * t.chainBonus : t.damage) * boost;

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
      if (_starved) _drawStarved(canvas);
    }
    _drawTierPips(canvas, game.iso.halfH);
    renderDamageOverlay(canvas);
  }

  /// A red "no power" marker so the player sees the BESS is starving this tower.
  void _drawStarved(Canvas canvas) {
    final y = -game.iso.halfH * 2.7;
    canvas.drawCircle(Offset(0, y), 6, Paint()..color = const Color(0xFFE23D4B));
    final x = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 1.6;
    canvas.drawLine(Offset(-2.5, y - 2.5), Offset(2.5, y + 2.5), x);
    canvas.drawLine(Offset(-2.5, y + 2.5), Offset(2.5, y - 2.5), x);
  }

  /// Scissor Barrier: two steel posts with a crossed scissor gate between them.
  void _renderBarrier(Canvas canvas) {
    final halfW = game.iso.halfW;
    final halfH = game.iso.halfH;

    // Slow-field hint (matches GridGuardGame.barrierSlowRadius = 1.5 tiles).
    const r = 1.5;
    final field = Rect.fromCenter(
        center: Offset.zero, width: 2 * r * halfW, height: 2 * r * halfH);
    canvas.drawOval(field, Paint()..color = spec.tint.withValues(alpha: 0.10));
    canvas.drawOval(
      field,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = spec.tint.withValues(alpha: 0.35),
    );

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

  /// 6300A Shock Transformer: real art when available (kule.png, one frame per
  /// tier), else a procedural orange housing with insulator stacks.
  void _renderTransformer(Canvas canvas) {
    final art = game.spritesFor('kule');
    if (art != null) {
      drawUnitSprite(canvas, art[tier.clamp(0, art.length - 1)],
          widthTiles: 1.15, sinkFrac: 0.26);
      return;
    }

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
    final emitter =
        _fireFlash > 0 ? const Color(0xFFFFFFFF) : const Color(0xFFFFC46B);
    canvas.drawCircle(
        const Offset(0, -8), _fireFlash > 0 ? 5 : 3.5, Paint()..color = emitter);
    canvas.restore();
  }

  void _drawTierPips(Canvas canvas, double halfH) {
    drawTierMark(canvas, tier, -halfH * 2.3);
  }
}
