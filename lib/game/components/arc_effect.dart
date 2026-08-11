import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../grid_guard_game.dart';

/// A short-lived jagged electric arc drawn between two tile positions — the
/// Shock Transformer's hit VFX. Sharp, geometric, no soft glow (per the design
/// language). Recomputes its zig-zag once and fades out fast.
class ArcEffect extends PositionComponent with HasGameReference<GridGuardGame> {
  ArcEffect({
    required this.fromTile,
    required this.toTile,
    required this.color,
    this.primary = true,
  }) : super(priority: 1 << 28);

  final Vector2 fromTile;
  final Vector2 toTile;
  final Color color;
  final bool primary;

  static final _rng = math.Random();
  final double _lifetime = 0.14;
  double _age = 0;
  List<Offset>? _points;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= _lifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final a = game.iso.tileToScreen(fromTile.x, fromTile.y) -
        Vector2(0, game.iso.halfH); // lift toward structure tops
    final b = game.iso.tileToScreen(toTile.x, toTile.y) -
        Vector2(0, game.iso.halfH * 0.6);

    _points ??= _buildJag(a.toOffset(), b.toOffset());
    final t = (_age / _lifetime).clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (primary ? 2.6 : 1.6) * (1.0 - t * 0.5)
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(1.0 - t);

    final path = Path()..moveTo(_points!.first.dx, _points!.first.dy);
    for (final p in _points!.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  List<Offset> _buildJag(Offset a, Offset b) {
    const segments = 6;
    final pts = <Offset>[a];
    final dir = b - a;
    final normal = Offset(-dir.dy, dir.dx);
    final len = normal.distance;
    final unitNormal = len == 0 ? Offset.zero : normal / len;
    for (var i = 1; i < segments; i++) {
      final f = i / segments;
      final base = a + dir * f;
      final jitter = (_rng.nextDouble() - 0.5) * 10;
      pts.add(base + unitNormal * jitter);
    }
    pts.add(b);
    return pts;
  }
}
