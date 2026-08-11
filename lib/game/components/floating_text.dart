import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../grid_guard_game.dart';

/// A "+N MW" style gain label that rises and fades. Purely cosmetic; it lives
/// at a tile position, drifts up in screen space, then removes itself.
class FloatingText extends PositionComponent
    with HasGameReference<GridGuardGame> {
  FloatingText({
    required this.text,
    required this.tile,
    required this.color,
    this.lifetime = 0.9,
  }) : super(priority: 1 << 29); // always above board objects

  final String text;
  final Vector2 tile;
  final Color color;
  final double lifetime;

  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= lifetime) {
      removeFromParent();
      return;
    }
    final base = game.iso.tileToScreen(tile.x, tile.y);
    position = Vector2(base.x, base.y - 20 - 30 * (_age / lifetime));
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / lifetime).clamp(0.0, 1.0);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withOpacity(1.0 - t),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
  }
}
