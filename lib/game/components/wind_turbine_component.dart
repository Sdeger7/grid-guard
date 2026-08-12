import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../models/level_config.dart';
import '../../models/tower_type.dart';
import 'iso_box.dart';
import 'iso_component.dart';

/// A Wind Turbine: an economy producer whose output the game scales by the wind
/// factor (works day AND night, unlike PV). Its blades spin faster when the wind
/// is stronger. Like PV panels, the game sums every turbine's output.
class WindTurbineComponent extends IsoComponent {
  WindTurbineComponent({
    required this.spec,
    required this.coord,
    this.tier = 0,
  }) : super(
          tile: Vector2(coord.col.toDouble(), coord.row.toDouble()),
          depthBias: 0.18,
        );

  final TowerSpec spec;
  final TileCoord coord;
  int tier;

  double _spin = 0;

  TowerTier get currentTier => spec.tier(tier);
  bool get canUpgrade => tier < spec.maxTier;
  int? get upgradeCost => canUpgrade ? spec.tier(tier + 1).cost : null;

  void upgrade() {
    if (canUpgrade) tier++;
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Blades track the wind — faster gusts, faster spin.
    _spin += dt * (1.0 + game.windFactor * 6.0);
  }

  @override
  void render(Canvas canvas) {
    final art = game.spritesFor('wind_turbine');
    if (art != null) {
      drawUnitSprite(canvas, art[tier.clamp(0, art.length - 1)],
          widthTiles: 1.5);
      return;
    }

    final halfW = game.iso.halfW;
    final halfH = game.iso.halfH;
    final poleH = halfH * (2.0 + 0.3 * tier);

    // Tapered pole.
    final poleShades = faceShades(const Color(0xFFDCE3EA));
    drawIsoBox(
      canvas,
      halfW: halfW,
      halfH: halfH,
      height: poleH,
      top: poleShades.top,
      left: poleShades.left,
      right: poleShades.right,
      footScale: 0.14,
    );

    // Nacelle + rotor at the top.
    final hub = Offset(0, -poleH - 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: hub, width: 12, height: 7),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFB8C4CE),
    );

    // Three blades.
    final bladeLen = halfH * 1.5 + tier * 3;
    final blade = Paint()
      ..color = const Color(0xFFF3F7FA)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final edge = Paint()
      ..color = const Color(0xFF9AA9B5)
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final a = _spin + i * (2 * math.pi / 3);
      final tip = hub + Offset(math.cos(a) * bladeLen, math.sin(a) * bladeLen * 0.7);
      canvas.drawLine(hub, tip, blade);
      canvas.drawLine(hub, tip, edge);
    }
    canvas.drawCircle(hub, 2.6, Paint()..color = const Color(0xFF6D7C88));

    for (var i = 0; i <= tier; i++) {
      canvas.drawCircle(Offset(-6 + i * 6.0, -poleH - 14), 2.0,
          Paint()..color = const Color(0xFFFFE08A));
    }
  }
}
