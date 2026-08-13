import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

import '../../data/skins.dart';
import 'enemy_component.dart';
import 'iso_box.dart';
import 'iso_component.dart';
import 'structure_component.dart';

/// A friendly interceptor drone. It launches from its bay, flies out to hunt the
/// nearest raider inside the bay's range, shoots it, and returns to orbit the
/// bay when there's nothing to chase. Answers the all-directions air raids that
/// static towers struggle to cover.
class InterceptorDrone extends IsoComponent {
  InterceptorDrone({required this.bay, required this.slot})
      : super(tile: bay.tile.clone(), depthBias: 0.6);

  final DroneBayComponent bay;

  /// Index in the bay's squadron — spreads drones around the idle orbit.
  final int slot;

  double _cooldown = 0;
  double _spin = 0;
  double _fireFlash = 0;
  EnemyComponent? _target;

  @override
  void update(double dt) {
    _spin += dt * 12;
    if (_fireFlash > 0) _fireFlash = (_fireFlash - dt).clamp(0, 1);
    if (_cooldown > 0) _cooldown -= dt;

    final t = bay.currentTier;

    // Drop a dead/out-of-range target.
    final cur = _target;
    if (cur == null ||
        cur.isDead ||
        (cur.tile - bay.tile).length > t.range + 1.0) {
      _target = bay.pickTarget();
    }

    final target = _target;
    if (target != null && !target.isDead) {
      // Close in and engage.
      final to = target.tile - tile;
      final dist = to.length;
      const speed = 3.2;
      if (dist > 0.55) {
        tile += to.normalized() * math.min(speed * dt, dist);
      }
      if (dist <= 1.6 && _cooldown <= 0 && game.tryDrawEnergy(t.energyCost)) {
        target.takeDamage(t.damage);
        game.spawnArc(tile.clone(), target.tile.clone(), primary: false);
        _cooldown = t.fireInterval;
        _fireFlash = 0.1;
      }
    } else {
      // Idle: orbit the bay.
      final a = _spin * 0.12 + slot * (2 * math.pi / 3);
      final orbit = Vector2(math.cos(a), math.sin(a)) * 0.9;
      final home = bay.tile + orbit;
      final to = home - tile;
      if (to.length > 0.05) {
        tile += to.normalized() * math.min(2.4 * dt, to.length);
      }
    }

    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final halfW = game.iso.halfW;
    final halfH = game.iso.halfH;
    final altitude = halfH * 2.1;

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset.zero, width: halfW * 0.3, height: halfH * 0.2),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );

    canvas.save();
    canvas.translate(0, -altitude);

    // Friendly interceptor, painted by whatever skin is equipped.
    final skin = game.skinFor(SkinSlot.drone);
    final body = _fireFlash > 0
        ? Color.lerp(skin.primary, const Color(0xFFFFFFFF), 0.7)!
        : skin.primary;
    final arm = Paint()
      ..color = skin.secondary
      ..strokeWidth = 2.4;
    for (final tp in [
      Offset(halfW * 0.42, -halfH * 0.2),
      Offset(-halfW * 0.42, -halfH * 0.2),
      Offset(halfW * 0.42, halfH * 0.2),
      Offset(-halfW * 0.42, halfH * 0.2),
    ]) {
      canvas.drawLine(Offset.zero, tp, arm);
      final s = 0.75 + 0.25 * math.sin(_spin + tp.dx);
      // Rotor hub + disc.
      canvas.drawCircle(tp, 2.6, Paint()..color = skin.secondary);
      canvas.drawOval(
        Rect.fromCenter(center: tp, width: 17 * s, height: 4.5),
        Paint()..color = skin.accent.withValues(alpha: 0.8),
      );
    }

    // Hull with a darker outline so it pops against grass.
    final hull =
        Rect.fromCenter(center: Offset.zero, width: 22, height: 13);
    canvas.drawOval(hull, Paint()..color = body);
    canvas.drawOval(
      hull,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = skin.secondary,
    );
    // Cockpit sensor.
    canvas.drawCircle(const Offset(0, -1.5), 3, Paint()..color = skin.accent);

    // Friendly marker ring above, so you can always find your own drones.
    canvas.drawCircle(
      const Offset(0, -13),
      3.2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = skin.primary,
    );
    canvas.restore();
  }
}

/// The Drone Bay: a landing pad that keeps a squadron of [InterceptorDrone]s in
/// the air. The bay itself doesn't shoot — its drones do.
class DroneBayComponent extends StructureComponent {
  DroneBayComponent({
    required super.spec,
    required super.coord,
    super.tier,
  }) : super(depthBias: 0.2);

  final List<InterceptorDrone> drones = [];
  double _beacon = 0;

  @override
  void upgrade() {
    super.upgrade();
    _syncSquadron();
  }

  /// Nearest live raider within range, for a drone to intercept.
  EnemyComponent? pickTarget() {
    EnemyComponent? best;
    var bestD = double.infinity;
    for (final e in game.enemies) {
      if (e.isDead) continue;
      final d = (e.tile - tile).length;
      if (d <= currentTier.range && d < bestD) {
        bestD = d;
        best = e;
      }
    }
    return best;
  }

  void _syncSquadron() {
    final want = currentTier.droneCount;
    while (drones.length < want) {
      final d = InterceptorDrone(bay: this, slot: drones.length);
      drones.add(d);
      parent?.add(d);
    }
  }

  @override
  void onMount() {
    super.onMount();
    _syncSquadron();
  }

  @override
  void onRemove() {
    for (final d in drones) {
      d.removeFromParent();
    }
    drones.clear();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _beacon += dt * 3;
  }

  @override
  void render(Canvas canvas) {
    final halfW = game.iso.halfW;
    final halfH = game.iso.halfH;

    // Low landing pad.
    final shades = faceShades(const Color(0xFF33465C));
    drawIsoBox(
      canvas,
      halfW: halfW,
      halfH: halfH,
      height: halfH * 0.35,
      top: shades.top,
      left: shades.left,
      right: shades.right,
      edge: spec.tint.withValues(alpha: 0.8),
      footScale: 0.8,
    );

    // Landing circle + pulsing beacon.
    canvas.save();
    canvas.translate(0, -halfH * 0.35);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset.zero, width: halfW * 0.9, height: halfH * 0.9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = spec.tint.withValues(alpha: 0.9),
    );
    final beat = 0.5 + 0.5 * math.sin(_beacon);
    canvas.drawCircle(Offset.zero, 2 + 1.5 * beat,
        Paint()..color = spec.tint.withValues(alpha: 0.4 + 0.4 * beat));
    canvas.restore();

    drawTierMark(canvas, tier, -halfH * 1.6);
    renderDamageOverlay(canvas);
  }
}
