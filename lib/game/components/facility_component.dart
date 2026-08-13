import 'dart:ui';

// TextPainter lives in the painting layer; TextDirection and friends come from
// dart:ui, so only the painter types are pulled in here to avoid a clash.
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;

import 'iso_box.dart';
import 'structure_component.dart';

/// A buildable grid facility with a fixed footprint: BESS units (add storage)
/// and Data Centers (earn money, draw power). Renders real art when present
/// ([spriteKey]) else a simple procedural box; the game aggregates their tier
/// stats.
class FacilityComponent extends StructureComponent {
  FacilityComponent({
    required super.spec,
    required super.coord,
    required this.spriteKey,
    required this.widthTiles,
    super.tier,
  }) : super(depthBias: 0.2);

  final String spriteKey;
  final double widthTiles;

  /// Facilities are the big fixed plant — sturdier than field equipment.
  @override
  double get baseMaxHealth => 110.0 + 70.0 * tier;

  @override
  void render(Canvas canvas) {
    final art = game.spritesFor(spriteKey);
    if (art != null) {
      drawUnitSprite(canvas, art[tier.clamp(0, art.length - 1)],
          widthTiles: widthTiles, sinkFrac: 0.22);
      _pips(canvas);
      renderDamageOverlay(canvas);
      return;
    }

    // Procedural fallback: a tinted box that grows a little per tier.
    final halfW = game.iso.halfW;
    final halfH = game.iso.halfH;
    final shades = faceShades(spec.tint);
    drawIsoBox(
      canvas,
      halfW: halfW,
      halfH: halfH,
      height: halfH * (1.0 + 0.25 * tier),
      top: shades.top,
      left: shades.left,
      right: shades.right,
      edge: const Color(0x66FFFFFF),
      footScale: 0.8,
    );
    _pips(canvas);
    renderDamageOverlay(canvas);
  }

  /// Tier markers. Buildings with many upgrade steps (the Intel Center has
  /// seven) would run a pip row off the side of the tile, so past three the
  /// count is drawn as a numeral instead.
  void _pips(Canvas canvas) {
    final y = -game.iso.halfH * 2.4;
    if (tier <= 2) {
      for (var i = 0; i <= tier; i++) {
        canvas.drawCircle(
            Offset(-6 + i * 6.0, y), 2.0, Paint()..color = const Color(0xFFFFE08A));
      }
      return;
    }
    final label = TextPainter(
      text: TextSpan(
        text: 'T${tier + 1}',
        style: const TextStyle(
          color: Color(0xFFFFE08A),
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(-label.width / 2, y - 5));
  }
}
