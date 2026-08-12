import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

import '../../models/enemy_type.dart';
import 'iso_box.dart';
import 'iso_component.dart';
import 'structure_component.dart';

/// An airborne hostile that flies in a straight line from its spawn point on the
/// map edge toward the base at the centre — raids come from all four sides, not
/// down a fixed lane. Slow fields (Scissor Barriers) drag it down wherever it
/// passes; reaching the centre damages the base.
class EnemyComponent extends IsoComponent {
  EnemyComponent({
    required this.spec,
    required this.maxHealth,
    required this.speed,
    required Vector2 spawn,
    required this.target,
  })  : health = maxHealth,
        super(tile: spawn.clone(), depthBias: 0.5);

  final EnemySpec spec;
  final double maxHealth;

  /// Base movement speed (tiles/sec), already scaled for the raid.
  final double speed;

  /// Tile position it flies toward (the base).
  final Vector2 target;

  double health;

  /// Distance travelled, in tile-space units (used for target prioritisation).
  double pathDistance = 0;

  bool _dead = false;
  double _hitFlash = 0;
  double _bob = 0;

  bool get isDead => _dead;
  bool get isAlive => !_dead;

  void takeDamage(double amount) {
    if (_dead) return;
    health -= amount;
    _hitFlash = 0.15;
    if (health <= 0) {
      _dead = true;
      game.onEnemyKilled(this);
      removeFromParent();
    }
  }

  /// Structure currently being strafed, if any. Raiders hit everything — panels,
  /// turbines, bays, towers — not just the base.
  StructureComponent? _prey;
  double _attackCooldown = 0;

  /// Seconds between strafing runs, and damage per run.
  static const double attackInterval = 1.1;
  double get attackDamage => spec.coreDamage * 1.6;

  @override
  void update(double dt) {
    if (_dead) return;

    _bob += dt * 6;
    if (_hitFlash > 0) _hitFlash = (_hitFlash - dt).clamp(0, 1);
    if (_attackCooldown > 0) _attackCooldown -= dt;

    // Re-acquire a nearby structure to maul; fall back to the base.
    final prey = _prey;
    if (prey == null || prey.isDestroyed || !prey.isMounted) {
      _prey = game.nearestStructureTo(tile, within: 2.6);
    }

    final aim = _prey?.tile ?? target;
    final slow = game.slowMultiplierAt(tile);
    final toAim = aim - tile;
    final dist = toAim.length;

    if (_prey != null) {
      // Hover over the structure and strafe it.
      if (dist > 0.5) {
        final step = speed * slow * dt;
        tile += toAim.normalized() * (step < dist ? step : dist);
        pathDistance += step;
      } else if (_attackCooldown <= 0) {
        game.enemyAttackStructure(this, _prey!);
        _attackCooldown = attackInterval;
      }
      super.update(dt);
      return;
    }

    if (dist <= 0.15) {
      game.onEnemyReachedCore(this);
      _dead = true;
      removeFromParent();
      return;
    }

    final step = speed * slow * dt;
    tile += toAim.normalized() * (step < dist ? step : dist);
    pathDistance += step;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final base = _hitFlash > 0
        ? Color.lerp(spec.tint, Colors.white, 0.6)!
        : spec.tint;
    if (spec.category == EnemyCategory.drone) {
      _renderDrone(canvas, base);
    } else {
      _renderMalware(canvas, base);
    }
  }

  /// Which of the three drone models to show: tougher raids field bigger craft.
  int get _sizeIndex {
    final ratio = maxHealth / spec.baseHealth;
    if (ratio < 1.6) return 0;
    if (ratio < 2.6) return 1;
    return 2;
  }

  /// Saboteur Drone: an airborne quadcopter flying well above the board — body,
  /// four spinning rotors, and a shadow cast on the ground below it.
  void _renderDrone(Canvas canvas, Color base) {
    final halfW = game.iso.halfW;
    final halfH = game.iso.halfH;
    // Cruising altitude + a gentle bob, drawn as a screen-space lift.
    final altitude = halfH * 1.9 + 2.0 * math.sin(_bob);

    // Shadow stays on the ground, under the flight position.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset.zero, width: halfW * 0.45, height: halfH * 0.3),
      Paint()..color = Colors.black.withValues(alpha: 0.14),
    );

    // Real art if present — pick the model by raid scaling.
    final art = game.spritesFor('sabodrone');
    if (art != null) {
      canvas.save();
      canvas.translate(0, -altitude);
      final sprite = art[_sizeIndex.clamp(0, art.length - 1)];
      final w = game.iso.tileWidth * (0.95 + 0.15 * _sizeIndex);
      final h = w * sprite.srcSize.y / sprite.srcSize.x;
      sprite.render(canvas,
          position: Vector2.zero(), size: Vector2(w, h), anchor: Anchor.center);
      canvas.restore();
      _drawHealthBar(canvas, halfW, halfH * 0.4 + altitude);
      return;
    }

    canvas.save();
    canvas.translate(0, -altitude);

    // Four arms + spinning rotors at the diagonal tips.
    final arm = Paint()
      ..color = const Color(0xFF2A2E36)
      ..strokeWidth = 2;
    final tips = [
      Offset(halfW * 0.34, -halfH * 0.18),
      Offset(-halfW * 0.34, -halfH * 0.18),
      Offset(halfW * 0.34, halfH * 0.18),
      Offset(-halfW * 0.34, halfH * 0.18),
    ];
    for (final tp in tips) {
      canvas.drawLine(Offset.zero, tp, arm);
      // Rotor disc — widens with the spin so it reads as turning.
      final spin = 0.75 + 0.25 * math.sin(_bob * 3 + tp.dx);
      canvas.drawOval(
        Rect.fromCenter(center: tp, width: 13 * spin, height: 4),
        Paint()..color = const Color(0x88AEB6C2),
      );
    }

    // Body.
    final shades = faceShades(base);
    drawIsoBox(
      canvas,
      halfW: halfW,
      halfH: halfH,
      height: halfH * 0.4,
      top: shades.top,
      left: shades.left,
      right: shades.right,
      footScale: 0.32,
    );
    // Sensor eye.
    canvas.drawCircle(Offset(0, -halfH * 0.4),
        2.2, Paint()..color = const Color(0xFFFFE08A));
    canvas.restore();

    _drawHealthBar(canvas, halfW, halfH * 0.4 + altitude);
  }

  /// Malware Gunship: a heavy airborne carrier — armoured hull with spikes,
  /// slung under twin lift rotors, flying lower and slower than the drone.
  void _renderMalware(Canvas canvas, Color base) {
    final halfW = game.iso.halfW;
    final halfH = game.iso.halfH;
    final shades = faceShades(base);
    final h = halfH * 0.85;
    final altitude = halfH * 1.35 + 1.5 * math.sin(_bob * 0.7);

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset.zero, width: halfW * 0.62, height: halfH * 0.4),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );

    // Real art: the gunship flies the heaviest craft in the sheet, tinted so it
    // still reads as the tanky variant rather than a plain drone.
    final art = game.spritesFor('sabodrone');
    if (art != null) {
      canvas.save();
      canvas.translate(0, -altitude);
      final sprite = art.last;
      final w = game.iso.tileWidth * 1.25;
      final sh = w * sprite.srcSize.y / sprite.srcSize.x;
      sprite.render(canvas,
          position: Vector2.zero(),
          size: Vector2(w, sh),
          anchor: Anchor.center,
          overridePaint: Paint()
            ..colorFilter =
                ColorFilter.mode(base.withValues(alpha: 0.45), BlendMode.srcATop));
      canvas.restore();
      _drawHealthBar(canvas, halfW, h + altitude);
      return;
    }

    canvas.save();
    canvas.translate(0, -altitude);

    // Twin lift rotors above the hull.
    for (final dx in [-halfW * 0.3, halfW * 0.3]) {
      canvas.drawLine(Offset(dx, -h), Offset(dx, -h - 5),
          Paint()
            ..color = const Color(0xFF2A2E36)
            ..strokeWidth = 2);
      final spin = 0.7 + 0.3 * math.sin(_bob * 2.5 + dx);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(dx, -h - 6), width: 20 * spin, height: 4),
        Paint()..color = const Color(0x88AEB6C2),
      );
    }

    drawIsoBox(
      canvas,
      halfW: halfW,
      halfH: halfH,
      height: h,
      top: shades.top,
      left: shades.left,
      right: shades.right,
      footScale: 0.62,
      edge: const Color(0x44000000),
    );

    // Spikes along the top ridge.
    final spike = Paint()..color = Color.lerp(base, Colors.black, 0.25)!;
    for (final dx in [-halfW * 0.28, 0.0, halfW * 0.28]) {
      final topY = -h;
      final p = Path()
        ..moveTo(dx - 3, topY)
        ..lineTo(dx, topY - 7)
        ..lineTo(dx + 3, topY)
        ..close();
      canvas.drawPath(p, spike);
    }
    // Glitchy sensor eye.
    canvas.drawRect(
      Rect.fromCenter(center: Offset(0, -h * 0.55), width: 8, height: 3),
      Paint()..color = const Color(0xFF3FE0D0),
    );
    canvas.restore();

    _drawHealthBar(canvas, halfW, h + altitude);
  }

  void _drawHealthBar(Canvas canvas, double halfW, double topY) {
    final frac = (health / maxHealth).clamp(0.0, 1.0);
    const w = 22.0;
    const barH = 3.0;
    final y = -topY - 8;
    final bg = Rect.fromLTWH(-w / 2, y, w, barH);
    canvas.drawRect(bg, Paint()..color = Colors.black.withValues(alpha: 0.45));
    canvas.drawRect(
      Rect.fromLTWH(-w / 2, y, w * frac, barH),
      Paint()
        ..color = frac > 0.5
            ? const Color(0xFF4CD07D)
            : const Color(0xFFE23D4B),
    );
  }
}
