import 'dart:ui';

/// Draws a beveled isometric box centered on the local origin, sitting on the
/// tile's base diamond and rising by [height] pixels. Three shaded faces (top /
/// left / right) give the boxy, engineered look the design calls for.
///
/// This is the single placeholder-geometry routine every structure uses; when
/// real sprites arrive, structures swap their `render` for a sprite draw and
/// this helper is simply no longer called.
void drawIsoBox(
  Canvas canvas, {
  required double halfW,
  required double halfH,
  required double height,
  required Color top,
  required Color left,
  required Color right,
  Color? edge,
  double footScale = 0.8,
}) {
  final hw = halfW * footScale;
  final hh = halfH * footScale;

  // Base diamond corners (on the ground).
  final bT = Offset(0, -hh);
  final bR = Offset(hw, 0);
  final bB = Offset(0, hh);
  final bL = Offset(-hw, 0);

  // Top diamond corners (raised).
  final tT = Offset(0, -hh - height);
  final tR = Offset(hw, -height);
  final tB = Offset(0, hh - height);
  final tL = Offset(-hw, -height);

  Path quad(Offset a, Offset b, Offset c, Offset d) => Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..lineTo(c.dx, c.dy)
    ..lineTo(d.dx, d.dy)
    ..close();

  // Left face.
  canvas.drawPath(quad(tL, tB, bB, bL), Paint()..color = left);
  // Right face.
  canvas.drawPath(quad(tB, tR, bR, bB), Paint()..color = right);
  // Top face (drawn last so it sits on top).
  canvas.drawPath(quad(tT, tR, tB, tL), Paint()..color = top);

  if (edge != null) {
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = edge;
    canvas.drawPath(quad(tT, tR, tB, tL), edgePaint);
    canvas.drawPath(quad(tL, tB, bB, bL), edgePaint);
    canvas.drawPath(quad(tB, tR, bR, bB), edgePaint);
  }
}

/// Convenience: derive three face shades from one base colour.
({Color top, Color left, Color right}) faceShades(Color base) => (
      top: Color.lerp(base, const Color(0xFFFFFFFF), 0.18)!,
      left: Color.lerp(base, const Color(0xFF000000), 0.28)!,
      right: Color.lerp(base, const Color(0xFF000000), 0.12)!,
    );
