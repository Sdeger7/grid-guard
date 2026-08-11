import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

import 'iso_component.dart';

/// What role a ground tile plays — drives its placeholder colour.
enum TileKind { ground, path, safeZone, core, spawn }

/// A single isometric ground diamond. Placeholder art: a flat-shaded diamond
/// with a thin edge. Rendering reads colours passed in from the zone theme, so
/// dropping in a real tile sprite later means swapping this component's paint
/// for a sprite draw — no other logic changes.
class GroundTile extends IsoComponent {
  GroundTile({
    required super.tile,
    required this.kind,
    required this.fill,
    required this.edge,
    required this.accent,
  });

  TileKind kind;
  Color fill;
  Color edge;
  Color accent;

  late final double _halfW = game.iso.halfW;
  late final double _halfH = game.iso.halfH;

  @override
  void update(double dt) {
    // Static tile — sync once is enough, but this is cheap and keeps it robust
    // to any world/camera changes.
    syncIso();
  }

  @override
  void render(Canvas canvas) {
    final path = Path()
      ..moveTo(0, -_halfH)
      ..lineTo(_halfW, 0)
      ..lineTo(0, _halfH)
      ..lineTo(-_halfW, 0)
      ..close();

    final fillPaint = Paint()..color = _fillColor();
    canvas.drawPath(path, fillPaint);

    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = edge;
    canvas.drawPath(path, edgePaint);

    // Neon inset for special tiles reads like a conduit outline.
    if (kind == TileKind.safeZone || kind == TileKind.spawn) {
      final inset = Path()
        ..moveTo(0, -_halfH * 0.6)
        ..lineTo(_halfW * 0.6, 0)
        ..lineTo(0, _halfH * 0.6)
        ..lineTo(-_halfW * 0.6, 0)
        ..close();
      canvas.drawPath(
        inset,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = accent.withValues(alpha: 0.8),
      );
    }
  }

  Color _fillColor() {
    switch (kind) {
      case TileKind.path:
        return Color.lerp(fill, Colors.black, 0.08)!;
      case TileKind.safeZone:
        return Color.lerp(fill, accent, 0.12)!;
      case TileKind.spawn:
        return Color.lerp(fill, accent, 0.2)!;
      case TileKind.core:
        return Color.lerp(fill, accent, 0.16)!;
      case TileKind.ground:
        return fill;
    }
  }
}
