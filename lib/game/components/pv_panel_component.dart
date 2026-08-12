import 'dart:ui';

import 'package:flame/components.dart';

import '../../models/level_config.dart';
import '../../models/tower_type.dart';
import 'iso_box.dart';
import 'structure_component.dart';

/// A PV Panel: a solar array on a safe-zone tile that feeds energy into the
/// BESS. It is a passive producer — the game sums every panel's output
/// ([GridGuardGame.pvOutput]) each tick, so the component itself just renders.
class PvPanelComponent extends StructureComponent {
  PvPanelComponent({
    required super.spec,
    required super.coord,
    super.tier,
  }) : super(depthBias: 0.18);

  @override
  void render(Canvas canvas) {
    // Use real art if it's been dropped into assets, else draw procedurally.
    final art = game.spritesFor('pv_panel');
    if (art != null) {
      drawUnitSprite(canvas, art[tier.clamp(0, art.length - 1)],
          widthTiles: 1.0, sinkFrac: 0.30);
      renderDamageOverlay(canvas);
      return;
    }

    final halfW = game.iso.halfW;
    final halfH = game.iso.halfH;

    // Steel pedestal.
    final baseShades = faceShades(const Color(0xFF464F5E));
    drawIsoBox(
      canvas,
      halfW: halfW,
      halfH: halfH,
      height: halfH * 0.45,
      top: baseShades.top,
      left: baseShades.left,
      right: baseShades.right,
      footScale: 0.4,
    );

    // Support strut up to the panel.
    canvas.drawLine(
      const Offset(0, 0),
      Offset(0, -halfH * 1.25),
      Paint()
        ..color = const Color(0xFF313A48)
        ..strokeWidth = 3,
    );

    // Tilted solar array (a diamond panel) floating above the strut.
    canvas.save();
    canvas.translate(0, -halfH * 1.35);
    final pw = halfW * 0.92, ph = halfH * 0.92;
    final t = Offset(0, -ph), r = Offset(pw, 0), b = Offset(0, ph), l = Offset(-pw, 0);
    final panel = Path()
      ..moveTo(t.dx, t.dy)
      ..lineTo(r.dx, r.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(l.dx, l.dy)
      ..close();
    canvas.drawPath(panel, Paint()..color = const Color(0xFF1E4E8C));

    // Photovoltaic cell grid: interpolate along opposite edges.
    Offset lerp(Offset a, Offset c, double f) =>
        Offset(a.dx + (c.dx - a.dx) * f, a.dy + (c.dy - a.dy) * f);
    final cell = Paint()
      ..color = const Color(0x804FA3FF)
      ..strokeWidth = 1;
    for (final f in const [0.25, 0.5, 0.75]) {
      canvas.drawLine(lerp(l, t, f), lerp(b, r, f), cell); // one axis
      canvas.drawLine(lerp(l, b, f), lerp(t, r, f), cell); // the other
    }
    // Bright frame + a sun glint on the upper-left cell.
    canvas.drawPath(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFFBFE0FF),
    );
    final glint = Path()
      ..moveTo(t.dx, t.dy)
      ..lineTo(lerp(t, r, 0.32).dx, lerp(t, r, 0.32).dy)
      ..lineTo(lerp(l, t, 0.68).dx, lerp(l, t, 0.68).dy)
      ..close();
    canvas.drawPath(glint, Paint()..color = const Color(0x66FFFFFF));
    canvas.restore();

    _tierPips(canvas, halfH);
    renderDamageOverlay(canvas);
  }

  void _tierPips(Canvas canvas, double halfH) {
    for (var i = 0; i <= tier; i++) {
      canvas.drawCircle(Offset(-6 + i * 6.0, -halfH * 2.2), 2.0,
          Paint()..color = const Color(0xFFFFE08A));
    }
  }
}
