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
        super(tile: Vector2.zero(), depthBias: 0.08, size: Vector2.all(28));

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
    final halfW = game.iso.halfW;
    final halfH = game.iso.halfH;

    final base = _hitFlash > 0
        ? Color.lerp(spec.tint, Colors.white, 0.6)!
        : spec.tint;
    final shades = faceShades(base);

    final isDrone = spec.category == EnemyCategory.drone;
    // Drones hover and are smaller; malware is a squat heavy box.
    final hover = isDrone ? (2.0 + 1.5 * math.sin(_bob)) : 0.0;
    final foot = isDrone ? 0.4 : 0.6;
    final h = isDrone ? halfH * 0.5 : halfH * 0.9;

    canvas.save();
    canvas.translate(0, -hover);
    drawIsoBox(
      canvas,
      halfW: halfW,
      halfH: halfH,
      height: h,
      top: shades.top,
      left: shades.left,
      right: shades.right,
      footScale: foot,
    );
    canvas.restore();

    _drawHealthBar(canvas, halfW, h + hover);
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
