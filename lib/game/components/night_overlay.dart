import 'dart:ui';

import 'package:flame/components.dart';

import '../grid_guard_game.dart';

/// A full-screen dusk-to-night tint over the board that deepens as the sun sets.
/// Added to the game root (screen space), above the world but below the Flutter
/// HUD, so only the play field darkens at night — reinforcing that PV has
/// stopped producing and the BESS is carrying the grid.
class NightOverlay extends PositionComponent
    with HasGameReference<GridGuardGame> {
  NightOverlay() : super(priority: 1 << 27);

  static const _maxAlpha = 0.34;

  @override
  void render(Canvas canvas) {
    final darkness = (1 - game.sunFactor);
    if (darkness <= 0.02) return;
    final alpha = (darkness * _maxAlpha).clamp(0.0, _maxAlpha);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, game.size.x, game.size.y),
      Paint()..color = const Color(0xFF0A1230).withValues(alpha: alpha),
    );
  }
}
