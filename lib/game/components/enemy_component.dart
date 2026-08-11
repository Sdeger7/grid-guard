import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

import '../../models/enemy_type.dart';
import 'iso_box.dart';
import 'iso_component.dart';

/// A hostile unit walking the path in tile space. Health/speed are the
/// already-scaled values for its wave; movement is driven by [pathDistance] along
/// [PathSystem], so it stays correct under any projection. Slow towers modulate
/// its speed via a per-tile multiplier the game supplies.
class EnemyComponent extends IsoComponent {
  EnemyComponent({
    required this.spec,
    required this.maxHealth,
    required this.speed,
  })  : health = maxHealth,
        super(tile: Vector2.zero(), depthBias: 0.08);

  final EnemySpec spec;
  final double maxHealth;

  /// Base movement speed (tiles/sec), already scaled for the wave.
  final double speed;

  double health;

  /// Distance travelled along the path, in tile-space units. Named
  /// `pathDistance` to avoid shadowing Flame's `PositionComponent.distance()`.
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

  @override
  void update(double dt) {
    if (_dead) return;
    final path = game.path;
    final currentTile = path.tileAtDistance(pathDistance);
    final slow = game.slowMultiplierAt(currentTile);
    pathDistance += speed * slow * dt;
    _bob += dt * 6;
    if (_hitFlash > 0) _hitFlash = (_hitFlash - dt).clamp(0, 1);

    if (pathDistance >= path.totalLength) {
      game.onEnemyReachedCore(this);
      _dead = true;
      removeFromParent();
      return;
    }
    tile = path.positionAtDistance(pathDistance);
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

  /// Saboteur Drone: a hovering quadcopter — body + four rotor arms.
  void _renderDrone(Canvas canvas, Color base) {
    final halfW = game.iso.halfW;
    final halfH = game.iso.halfH;
    final hover = 3.0 + 1.6 * math.sin(_bob);

    canvas.save();
    canvas.translate(0, -hover);

    // Faint ground shadow.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, hover), width: halfW * 0.5, height: halfH * 0.35),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );

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
      canvas.drawOval(
        Rect.fromCenter(center: tp, width: 11, height: 5),
        Paint()..color = const Color(0x66AEB6C2),
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

    _drawHealthBar(canvas, halfW, halfH * 0.4 + hover);
  }

  /// Malware Crawler: a squat armoured slab with spikes and a glitch slice.
  void _renderMalware(Canvas canvas, Color base) {
    final halfW = game.iso.halfW;
    final halfH = game.iso.halfH;
    final shades = faceShades(base);
    final h = halfH * 0.85;

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

    _drawHealthBar(canvas, halfW, h);
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
