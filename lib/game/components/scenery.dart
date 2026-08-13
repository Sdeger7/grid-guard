import 'dart:math' as math;
import 'dart:ui';

import '../../data/skins.dart';
import 'iso_component.dart';

/// What a scenery prop is.
enum SceneryKind { tree, pine, bush, rock, reeds }

/// A decorative prop standing on a tile: trees, rocks, bushes, reeds at the
/// water's edge. Purely cosmetic — the yard stays buildable everywhere, so a
/// prop simply stops drawing once something real is built on its tile (the
/// operator cleared it to pour a pad).
class SceneryComponent extends IsoComponent {
  SceneryComponent({
    required super.tile,
    required this.kind,
    required this.seed,
  }) : super(depthBias: 0.05);

  final SceneryKind kind;

  /// Stable per-prop randomness, so nothing wobbles between frames.
  final double seed;

  @override
  void update(double dt) => syncIso();

  @override
  void render(Canvas canvas) {
    if (game.isOccupiedTile(tile.x.round(), tile.y.round())) return;

    final halfW = game.iso.halfW;
    final halfH = game.iso.halfH;

    // Everything casts a soft contact shadow so props sit *on* the grass
    // instead of floating above it.
    void shadow(double w) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(0, halfH * 0.1), width: w, height: w * 0.45),
        Paint()..color = const Color(0x33000000),
      );
    }

    switch (kind) {
      case SceneryKind.tree:
        _tree(canvas, halfW, halfH, shadow);
        break;
      case SceneryKind.pine:
        _pine(canvas, halfW, halfH, shadow);
        break;
      case SceneryKind.bush:
        _bush(canvas, halfW, halfH, shadow);
        break;
      case SceneryKind.rock:
        _rock(canvas, halfW, halfH, shadow);
        break;
      case SceneryKind.reeds:
        _reeds(canvas, halfW, halfH);
        break;
    }
  }

  void _tree(Canvas canvas, double halfW, double halfH, void Function(double) shadow) {
    final scale = 0.85 + seed * 0.35;
    shadow(halfW * 0.5 * scale);

    final trunkTop = -halfH * 1.5 * scale;
    canvas.drawRect(
      Rect.fromLTRB(-2.0 * scale, trunkTop, 2.0 * scale, halfH * 0.1),
      Paint()..color = const Color(0xFF6B4A2F),
    );

    // Three overlapping blobs make a fuller canopy than one circle.
    final leaf = Color.lerp(const Color(0xFF2E7D3A), const Color(0xFF57A64A),
        (seed * 1.7) % 1.0)!;
    for (final o in [
      Offset(-6 * scale, trunkTop + 2),
      Offset(6 * scale, trunkTop + 4),
      Offset(0, trunkTop - 6 * scale),
    ]) {
      canvas.drawCircle(o, 9.5 * scale, Paint()..color = leaf);
    }
    // Sun-side highlight.
    canvas.drawCircle(
      Offset(4 * scale, trunkTop - 9 * scale),
      5 * scale,
      Paint()..color = Color.lerp(leaf, const Color(0xFFCDEBA0), 0.45)!,
    );
  }

  void _pine(Canvas canvas, double halfW, double halfH, void Function(double) shadow) {
    final scale = 0.9 + seed * 0.3;
    shadow(halfW * 0.42 * scale);

    canvas.drawRect(
      Rect.fromLTRB(-1.8 * scale, -halfH * 0.5, 1.8 * scale, halfH * 0.12),
      Paint()..color = const Color(0xFF5C4028),
    );

    final dark = Color.lerp(const Color(0xFF1F5E33), const Color(0xFF2F7A42),
        (seed * 2.3) % 1.0)!;
    for (var i = 0; i < 3; i++) {
      final top = -halfH * (0.7 + 0.55 * (i + 1)) * scale;
      final spread = (11.0 - i * 2.6) * scale;
      final base = top + 11 * scale;
      final tri = Path()
        ..moveTo(0, top)
        ..lineTo(spread, base)
        ..lineTo(-spread, base)
        ..close();
      canvas.drawPath(
          tri,
          Paint()
            ..color = Color.lerp(dark, const Color(0xFF8FD07A), i * 0.12)!);
    }
  }

  void _bush(Canvas canvas, double halfW, double halfH, void Function(double) shadow) {
    final scale = 0.8 + seed * 0.4;
    shadow(halfW * 0.34 * scale);
    final leaf = Color.lerp(const Color(0xFF3B8442), const Color(0xFF6FB255),
        (seed * 3.1) % 1.0)!;
    for (final o in [
      Offset(-5 * scale, -3 * scale),
      Offset(5 * scale, -2 * scale),
      Offset(0, -7 * scale),
    ]) {
      canvas.drawCircle(o, 5.5 * scale, Paint()..color = leaf);
    }
    // A few berries on some bushes, for colour against all the green.
    if (seed > 0.72) {
      final berry = Paint()..color = const Color(0xFFE0574B);
      canvas.drawCircle(Offset(-3 * scale, -6 * scale), 1.5, berry);
      canvas.drawCircle(Offset(4 * scale, -4 * scale), 1.5, berry);
    }
  }

  void _rock(Canvas canvas, double halfW, double halfH, void Function(double) shadow) {
    final scale = 0.8 + seed * 0.5;
    shadow(halfW * 0.32 * scale);
    final stone = Color.lerp(const Color(0xFF7C8894), const Color(0xFFA7B1BB),
        (seed * 1.3) % 1.0)!;
    final body = Path()
      ..moveTo(-7 * scale, halfH * 0.05)
      ..lineTo(-4 * scale, -6 * scale)
      ..lineTo(2 * scale, -8 * scale)
      ..lineTo(7 * scale, -2 * scale)
      ..lineTo(5 * scale, halfH * 0.08)
      ..close();
    canvas.drawPath(body, Paint()..color = stone);
    // Lit facet.
    final facet = Path()
      ..moveTo(-4 * scale, -6 * scale)
      ..lineTo(2 * scale, -8 * scale)
      ..lineTo(1 * scale, -3 * scale)
      ..close();
    canvas.drawPath(facet,
        Paint()..color = Color.lerp(stone, const Color(0xFFE8EEF3), 0.5)!);
  }

  void _reeds(Canvas canvas, double halfW, double halfH) {
    final blade = Paint()
      ..color = const Color(0xFF4E8B3C)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final a = (seed + i * 0.23) % 1.0;
      final bx = (a - 0.5) * halfW * 0.8;
      final lean = (a - 0.5) * 5;
      canvas.drawLine(Offset(bx, halfH * 0.1),
          Offset(bx + lean, -7 - a * 6), blade);
    }
  }
}

/// A pond: one flat water tile. Ponds are drawn as part of the terrain (below
/// everything) and simply get covered over if the player builds on them.
class PondTile extends IsoComponent {
  // Just above the grass it replaces, but below props and structures.
  PondTile({required super.tile, required this.seed, required this.edges})
      : super(depthBias: 0.02);

  final double seed;

  /// Which sides border dry land — those get a sandy shore.
  final bool edges;

  double _ripple = 0;

  @override
  void update(double dt) {
    _ripple += dt;
    syncIso();
  }

  @override
  void render(Canvas canvas) {
    // Built on means drained and backfilled — the grass below shows through.
    if (game.isOccupiedTile(tile.x.round(), tile.y.round())) return;

    final w = game.iso.halfW * 1.06;
    final h = game.iso.halfH * 1.06;
    final diamond = Path()
      ..moveTo(0, -h)
      ..lineTo(w, 0)
      ..lineTo(0, h)
      ..lineTo(-w, 0)
      ..close();

    if (edges) {
      // Sandy rim under the water so the shoreline isn't a hard cut.
      canvas.drawPath(diamond, Paint()..color = const Color(0xFFC8B98A));
    }

    final inset = edges ? 0.82 : 1.0;
    final water = Path()
      ..moveTo(0, -h * inset)
      ..lineTo(w * inset, 0)
      ..lineTo(0, h * inset)
      ..lineTo(-w * inset, 0)
      ..close();
    canvas.drawPath(
      water,
      Paint()
        ..color = Color.lerp(
            game.skinFor(SkinSlot.terrain).accent,
            const Color(0xFF3E9CBF),
            (seed * 1.9) % 1.0 * 0.4)!,
    );

    // Slow highlight bands, so the surface is alive without being busy.
    final shine = Paint()..color = const Color(0x33FFFFFF);
    for (var i = 0; i < 2; i++) {
      final t = math.sin(_ripple * 0.6 + seed * 6 + i * 2.1);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(t * w * 0.18, -h * 0.15 + i * h * 0.4),
          width: w * 0.7,
          height: h * 0.16,
        ),
        shine,
      );
    }
  }
}
