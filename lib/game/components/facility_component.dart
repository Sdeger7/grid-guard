import 'dart:ui';

import '../../data/skins.dart';
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

  /// Which contract this Data Center runs. Each one is booked separately, so a
  /// site can mine on one machine and host bank records on another.
  int workloadIndex = 0;

  /// Position in the site's Data Center list, for naming ("DC 2").
  int dcIndex = 0;

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
    // Tinted toward the equipped structure skin, so a site reads as one kit.
    final skin = game.skinFor(SkinSlot.structure);
    final shades = faceShades(Color.lerp(spec.tint, skin.primary, 0.45)!);
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

  void _pips(Canvas canvas) {
    drawTierMark(canvas, tier, -game.iso.halfH * 2.4,
        color: game.skinFor(SkinSlot.structure).accent);
  }
}
