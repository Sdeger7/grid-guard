import 'dart:ui';

import 'package:flame/components.dart';

import '../../models/level_config.dart';
import '../../models/tower_type.dart';
import 'iso_box.dart';
import 'iso_component.dart';

/// A PV Panel: an economy structure on a safe-zone tile that generates MW over
/// time and pops floating "+MW" gain text on each payout.
class PvPanelComponent extends IsoComponent {
  PvPanelComponent({
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

  double _accum = 0;

  TowerTier get currentTier => spec.tier(tier);
  bool get canUpgrade => tier < spec.maxTier;
  int? get upgradeCost => canUpgrade ? spec.tier(tier + 1).cost : null;

  void upgrade() {
    if (canUpgrade) tier++;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _accum += currentTier.mwPerSecond * dt;
    // Pay out in whole-MW chunks and float the gain text.
    if (_accum >= 1.0) {
      final gain = _accum.floor();
      _accum -= gain;
      game.addMw(gain);
      game.spawnFloatingText('+$gain MW', tile.clone(), spec.tint);
    }
  }

  @override
  void render(Canvas canvas) {
    final halfW = game.iso.halfW;
    final halfH = game.iso.halfH;
    final shades = faceShades(spec.tint);

    // Short base with an angled panel on top.
    drawIsoBox(
      canvas,
      halfW: halfW,
      halfH: halfH,
      height: halfH * 0.5,
      top: shades.top,
      left: shades.left,
      right: shades.right,
      footScale: 0.75,
    );

    // Tilted PV surface as a lighter diamond floating just above.
    canvas.save();
    canvas.translate(0, -halfH * 0.8);
    final panel = Path()
      ..moveTo(0, -halfH * 0.5)
      ..lineTo(halfW * 0.7, 0)
      ..lineTo(0, halfH * 0.5)
      ..lineTo(-halfW * 0.7, 0)
      ..close();
    canvas.drawPath(panel, Paint()..color = shades.top);
    canvas.drawPath(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFFEAF3FF),
    );
    // Cell grid lines.
    final line = Paint()
      ..color = const Color(0x66102040)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(-halfW * 0.35, -halfH * 0.25),
        Offset(halfW * 0.35, halfH * 0.25), line);
    canvas.drawLine(Offset(halfW * 0.35, -halfH * 0.25),
        Offset(-halfW * 0.35, halfH * 0.25), line);
    canvas.restore();

    for (var i = 0; i <= tier; i++) {
      canvas.drawCircle(Offset(-6 + i * 6.0, -halfH * 1.6), 2.0,
          Paint()..color = const Color(0xFFFFFFFF));
    }
  }
}
