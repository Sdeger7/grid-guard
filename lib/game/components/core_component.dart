import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

import 'iso_box.dart';
import 'iso_component.dart';

/// The BESS 1M battery core + Core 40 PMDC the player defends. Visually the
/// largest structure on the board; enemies that reach it deal integrity damage
/// (tracked by the game, not here). Flashes red when hit.
class CoreComponent extends IsoComponent {
  CoreComponent({required super.tile, required this.accent})
      : super(depthBias: 0.15);

  final Color accent;
  double _flash = 0;

  void flashDamage() => _flash = 0.35;

  @override
  void update(double dt) {
    super.update(dt);
    if (_flash > 0) _flash = (_flash - dt).clamp(0, 1);
  }

  @override
  void render(Canvas canvas) {
    final halfW = game.iso.halfW;
    final halfH = game.iso.halfH;

    // Base slab (BESS enclosure).
    final base = _flash > 0
        ? Color.lerp(const Color(0xFF2B3550), Colors.red, _flash)!
        : const Color(0xFF2B3550);
    final shades = faceShades(base);
    drawIsoBox(
      canvas,
      halfW: halfW,
      halfH: halfH,
      height: halfH * 1.6,
      top: shades.top,
      left: shades.left,
      right: shades.right,
      edge: accent.withValues(alpha: 0.7),
      footScale: 0.9,
    );

    // Glowing core cap (Core 40 PMDC).
    final capShades = faceShades(accent);
    canvas.save();
    canvas.translate(0, -halfH * 1.6);
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
  }
}
