import 'dart:math' as math;
import 'dart:ui';

import '../../data/skins.dart';
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

  /// Set for tiles on the outer ring — they fade into the surrounding field so
  /// the map doesn't end on a hard cut edge.
  bool isEdge = false;

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
    // The terrain skin decides what this ground is made of.
    final skin = game.skinFor(SkinSlot.terrain);
    var grass = _n < 0.5
        ? Color.lerp(skin.primary, skin.secondary, _n * 0.35)!
        : Color.lerp(skin.primary, const Color(0xFFF2F7D8), (_n - 0.5) * 0.18)!;
    // Outer ring blends toward the darker surrounding field.
    if (isEdge) {
      grass = Color.lerp(grass, skin.secondary, 0.55)!;
    }
    // Ground takes the light: warm and washed out under a high sun, deep and
    // desaturated after dark. Without this the board reads as the same picture
    // at noon and midnight, which is the single biggest thing that made it look
    // flat.
    final elevation = game.sun.elevationDegrees;
    if (elevation > 2) {
      grass = Color.lerp(grass, const Color(0xFFFFF6D8),
          (elevation / 90 * 0.22).clamp(0.0, 0.22))!;
    } else {
      final night = ((2 - elevation) / 14).clamp(0.0, 1.0);
      grass = Color.lerp(grass, const Color(0xFF14203A), 0.45 * night)!;
    }

    canvas.drawPath(diamond, Paint()..color = grass);

    // A few blades of grass for texture (skipped on the base's own tile).
    if (kind != TileKind.core) {
      final tuft = Paint()
        ..color = Color.lerp(grass, skin.secondary, 0.45)!
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

    // A soft vignette toward the map edge, so the yard reads as a place with a
    // horizon rather than a diamond floating in green.
    if (isEdge) {
      canvas.drawPath(
        diamond,
        Paint()
          ..color = const Color(0xFF0B1220).withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
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
