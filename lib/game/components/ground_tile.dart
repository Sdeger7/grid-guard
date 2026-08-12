import 'dart:math' as math;
import 'dart:ui';

import 'iso_component.dart';

/// What role a ground tile plays.
enum TileKind { ground, path, safeZone, core, spawn }

/// One cell of the terrain, drawn as seamless green grass.
///
/// There is deliberately no tile outline or checker: neighbouring diamonds are
/// drawn slightly overlapping in near-identical greens, so the field reads as a
/// continuous lawn rather than a grid. A little per-tile noise (seeded from the
/// coordinate, so it never flickers) plus a few grass tufts give it texture.
class GroundTile extends IsoComponent {
  GroundTile({
    required super.tile,
    required this.kind,
    required this.fill,
    required this.road,
    required this.accent,
  });

  TileKind kind;
  Color fill;
  Color road;
  Color accent;

  late final double _halfW = game.iso.halfW;
  late final double _halfH = game.iso.halfH;

  /// Stable pseudo-random in [0,1) derived from the tile coordinate.
  late final double _n = _hash(tile.x.round(), tile.y.round());
  late final double _n2 = _hash(tile.y.round() + 31, tile.x.round() + 7);

  static double _hash(int a, int b) {
    final h = (a * 73856093) ^ (b * 19349663);
    return ((h & 0x7fffffff) % 1000) / 1000.0;
  }

  @override
  void update(double dt) {
    syncIso();
  }

  @override
  void render(Canvas canvas) {
    // Overlap neighbours slightly so no seam or grid line can show through.
    const bleed = 1.06;
    final w = _halfW * bleed, h = _halfH * bleed;
    final diamond = Path()
      ..moveTo(0, -h)
      ..lineTo(w, 0)
      ..lineTo(0, h)
      ..lineTo(-w, 0)
      ..close();

    // Grass with a subtle per-tile shade shift (lerp keeps this portable across
    // Flutter colour APIs).
    final grass = _n < 0.5
        ? Color.lerp(fill, const Color(0xFF2F5F2A), _n * 0.22)!
        : Color.lerp(fill, const Color(0xFFBFE08A), (_n - 0.5) * 0.20)!;
    canvas.drawPath(diamond, Paint()..color = grass);

    // A few blades of grass for texture (skipped on the base's own tile).
    if (kind != TileKind.core) {
      final tuft = Paint()
        ..color = Color.lerp(grass, const Color(0xFF2F6B33), 0.35)!
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;
      final count = 2 + (_n * 3).floor();
      for (var i = 0; i < count; i++) {
        final a = (_n2 + i * 0.37) * math.pi * 2;
        final r = 0.25 + ((_n + i * 0.19) % 1.0) * 0.55;
        final bx = math.cos(a) * _halfW * r;
        final by = math.sin(a) * _halfH * r;
        final lean = ((_n2 + i * 0.11) % 1.0 - 0.5) * 3;
        canvas.drawLine(
            Offset(bx, by), Offset(bx + lean, by - 4 - _n * 3), tuft);
      }
    }

    // The base's tile keeps a faint pad so the centre reads as prepared ground.
    if (kind == TileKind.core) {
      final pad = Path()
        ..moveTo(0, -_halfH * 0.8)
        ..lineTo(_halfW * 0.8, 0)
        ..lineTo(0, _halfH * 0.8)
        ..lineTo(-_halfW * 0.8, 0)
        ..close();
      canvas.drawPath(
          pad, Paint()..color = const Color(0xFF9AA3A8).withValues(alpha: 0.55));
    }
  }
}
