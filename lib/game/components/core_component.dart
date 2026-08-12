import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart' show Colors;

import 'iso_box.dart';
import 'iso_component.dart';

/// The BESS 1M battery core + Core 40 PMDC the player defends. Visually the
/// largest structure on the board: a battery enclosure with charge shelves and
/// a pulsing beacon on the data-center cap. Flashes red when hit.
class CoreComponent extends IsoComponent {
  CoreComponent({required super.tile, required this.accent})
      : super(depthBias: 0.15);

  final Color accent;
  double _flash = 0;
  double _pulse = 0;

  void flashDamage() => _flash = 0.35;

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt * 3;
    if (_flash > 0) _flash = (_flash - dt).clamp(0, 1);
  }

  @override
  void render(Canvas canvas) {
    // Real art if present: BESS drawn behind-left, Data Center (core) in front.
    final dc = game.spritesFor('core');
    final bess = game.spritesFor('bess');
    if (dc != null || bess != null) {
      if (bess != null) {
        canvas.save();
        canvas.translate(-game.iso.halfW * 0.85, -game.iso.halfH * 0.2);
        drawUnitSprite(canvas, bess.first, widthTiles: 1.7, baseLift: 0.5);
        canvas.restore();
      }
      if (dc != null) {
        drawUnitSprite(canvas, dc.first, widthTiles: 2.2, baseLift: 0.5);
      }
      return;
    }

    final halfW = game.iso.halfW;
    final halfH = game.iso.halfH;

    final base = _flash > 0
        ? Color.lerp(const Color(0xFF2B3550), Colors.red, _flash)!
        : const Color(0xFF2B3550);
    final shades = faceShades(base);
    final height = halfH * 1.6;
    final hw = halfW * 0.9;

    drawIsoBox(
      canvas,
      halfW: halfW,
      halfH: halfH,
      height: height,
      top: shades.top,
      left: shades.left,
      right: shades.right,
      edge: accent.withValues(alpha: 0.7),
      footScale: 0.9,
    );

    // Charge shelves across the right face (battery rack rows).
    final shelf = Paint()
      ..color = accent.withValues(alpha: 0.55)
      ..strokeWidth = 1.4;
    final hhFoot = halfH * 0.9;
    for (final f in const [0.28, 0.5, 0.72]) {
      final a = Offset(0, hhFoot - height * (1 - f));
      final b = Offset(hw, -height * (1 - f));
      canvas.drawLine(a, b, shelf);
    }
    // A couple of vertical dividers.
    for (final vx in [hw * 0.4, hw * 0.72]) {
      canvas.drawLine(
        Offset(vx, hhFoot * (1 - vx / hw) - height),
        Offset(vx, hhFoot * (1 - vx / hw)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..strokeWidth = 1,
      );
    }

    // Data-center cap (Core 40 PMDC).
    final capShades = faceShades(accent);
    canvas.save();
    canvas.translate(0, -height);
    drawIsoBox(
      canvas,
      halfW: halfW,
      halfH: halfH,
      height: halfH * 0.5,
      top: capShades.top,
      left: capShades.left,
      right: capShades.right,
      footScale: 0.5,
    );
    canvas.restore();

    // Pulsing beacon on top of the cap.
    final beat = 0.5 + 0.5 * math.sin(_pulse);
    final beaconY = -(height + halfH * 0.5);
    canvas.drawCircle(
      Offset(0, beaconY),
      3 + 2 * beat,
      Paint()..color = accent.withValues(alpha: 0.25 + 0.35 * beat),
    );
    canvas.drawCircle(
      Offset(0, beaconY),
      2.4,
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }
}
