import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../grid_guard_game.dart';

/// A short, sharp geometric burst played when an enemy dies — expanding shards
/// plus a thin ring, in the enemy's colour. Matches the design's crisp,
/// non-glowy VFX language.
class BurstEffect extends PositionComponent with HasGameReference<GridGuardGame> {
  BurstEffect({required this.tile, required this.color})
      : super(priority: 1 << 28);

  final Vector2 tile;
  final Color color;

  static const double _life = 0.28;
  static const int _shards = 7;
  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= _life) {
      removeFromParent();
      return;
    }
    position = game.iso.tileToScreen(tile.x, tile.y) -
        Vector2(0, game.iso.halfH * 0.5);
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / _life).clamp(0.0, 1.0);
    final r = 4 + 22 * t;
    final alpha = 1 - t;

    final shard = Paint()
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = 2.2 * (1 - t * 0.6)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < _shards; i++) {
      final a = (i / _shards) * math.pi * 2;
      // Flatten Y to sit in the isometric plane.
      final inner = Offset(math.cos(a) * r * 0.35, math.sin(a) * r * 0.35 * 0.6);
      final outer = Offset(math.cos(a) * r, math.sin(a) * r * 0.6);
      canvas.drawLine(inner, outer, shard);
    }

    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * (1 - t)
        ..color = color.withValues(alpha: alpha * 0.6),
    );
  }
}
