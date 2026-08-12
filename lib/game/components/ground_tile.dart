import 'dart:ui';

import 'package:flutter/material.dart' show Colors;

import 'iso_component.dart';

/// What role a ground tile plays — drives its placeholder look.
enum TileKind { ground, path, safeZone, core, spawn }

/// A single isometric ground diamond.
///
/// Rendering is role-based so the board reads as a *place*, not a chessboard:
/// plain ground is a flat unified fill with only a whisper of an edge; the
/// enemy route is a darker connected "lane"; buildable cells are drawn as
/// raised, accent-bordered pads. Colours come from the zone theme, so real tile
/// sprites can replace this paint later with no logic change.
class GroundTile extends IsoComponent {
  GroundTile({
    required super.tile,
    required this.kind,
    required this.fill,
    required this.road,
    required this.accent,
  });

  TileKind kind;

  /// Base ground colour.
  Color fill;

  /// Colour of the enemy lane.
  Color road;
  Color accent;

  late final double _halfW = game.iso.halfW;
  late final double _halfH = game.iso.halfH;

  @override
  void update(double dt) {
    // Static tile — a single sync is enough, and it's cheap.
    syncIso();
  }

  Path _diamond(double s) => Path()
    ..moveTo(0, -_halfH * s)
    ..lineTo(_halfW * s, 0)
    ..lineTo(0, _halfH * s)
    ..lineTo(-_halfW * s, 0)
    ..close();

  Paint _stroke(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..color = c;

  @override
  void render(Canvas canvas) {
    final base = _diamond(1.0);

    switch (kind) {
      case TileKind.ground:
        canvas.drawPath(base, Paint()..color = fill);
        // Barely-there edge: enough for depth, not a grid.
        canvas.drawPath(base, _stroke(Colors.black.withValues(alpha: 0.05), 1));
        break;

      case TileKind.path:
        canvas.drawPath(base, Paint()..color = road);
        canvas.drawPath(base, _stroke(Colors.black.withValues(alpha: 0.10), 1));
        break;

      case TileKind.spawn:
        canvas.drawPath(base, Paint()..color = road);
        canvas.drawPath(base, _stroke(accent.withValues(alpha: 0.9), 1.6));
        _dot(canvas, accent);
        break;

      case TileKind.safeZone:
        canvas.drawPath(base, Paint()..color = fill);
        _drawPad(canvas, Color.lerp(fill, accent, 0.16)!);
        break;

      case TileKind.core:
        // The base's own tile: a bright reserved platform at the map centre.
        canvas.drawPath(base, Paint()..color = fill);
        _drawPad(canvas, Color.lerp(fill, accent, 0.36)!);
        break;
    }
  }

  /// A raised, accent-bordered platform that reads as "buildable here".
  void _drawPad(Canvas canvas, Color padColor) {
    final pad = _diamond(0.74);
    // Soft drop shadow for a hint of height.
    canvas.save();
    canvas.translate(0, 2);
    canvas.drawPath(pad, Paint()..color = Colors.black.withValues(alpha: 0.08));
    canvas.restore();

    canvas.drawPath(pad, Paint()..color = padColor);
    canvas.drawPath(pad, _stroke(accent.withValues(alpha: 0.85), 1.4));
  }

  void _dot(Canvas canvas, Color c) {
    canvas.drawCircle(Offset.zero, 3, Paint()..color = c);
  }
}
