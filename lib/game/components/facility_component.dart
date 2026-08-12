import 'dart:ui';

import 'package:flame/components.dart';

import '../../models/level_config.dart';
import '../../models/tower_type.dart';
import 'iso_box.dart';
import 'iso_component.dart';

/// A buildable grid facility with a fixed footprint: BESS units (add storage)
/// and Data Centers (earn money, draw power). Renders real art when present
/// ([spriteKey]) else a simple procedural box; the game aggregates their tier
/// stats.
class FacilityComponent extends IsoComponent {
  FacilityComponent({
    required this.spec,
    required this.coord,
    required this.spriteKey,
    required this.widthTiles,
    this.tier = 0,
  }) : super(
          tile: Vector2(coord.col.toDouble(), coord.row.toDouble()),
          depthBias: 0.2,
        );

  final TowerSpec spec;
  final TileCoord coord;
  final String spriteKey;
  final double widthTiles;
  int tier;

  TowerTier get currentTier => spec.tier(tier);
  bool get canUpgrade => tier < spec.maxTier;
  int? get upgradeCost => canUpgrade ? spec.tier(tier + 1).cost : null;

  void upgrade() {
    if (canUpgrade) tier++;
  }

  @override
  void render(Canvas canvas) {
    final art = game.spritesFor(spriteKey);
    if (art != null) {
      drawUnitSprite(canvas, art[tier.clamp(0, art.length - 1)],
          widthTiles: widthTiles, sinkFrac: 0.22);
      _pips(canvas);
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
  }

  void _pips(Canvas canvas) {
    for (var i = 0; i <= tier; i++) {
      canvas.drawCircle(Offset(-6 + i * 6.0, -game.iso.halfH * 2.4), 2.0,
          Paint()..color = const Color(0xFFFFE08A));
    }
  }
}
