import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../grid_guard_game.dart';

/// The light over the site.
///
/// The game already knows exactly where the sun is — its real elevation above
/// the site's own horizon — and that number is far more useful to look at than
/// it was to compute. A flat dusk tint threw away all of it. This grades the
/// whole board through the day the way daylight actually behaves: cold and blue
/// before dawn, warm and low at sunrise, clear and neutral at noon, deep amber
/// through sunset, and dark blue overnight with the structures' own lights
/// carrying the scene.
///
/// It renders in screen space above the world and below the HUD, so only the
/// play field is graded.
class SkyOverlay extends PositionComponent
    with HasGameReference<GridGuardGame> {
  SkyOverlay() : super(priority: 1 << 27);

  /// Colour and strength of the wash at a given sun elevation, in degrees.
  static ({Color tint, double strength}) gradeFor(double elevation) {
    if (elevation <= -12) {
      // Full night: deep blue, strong enough to read as dark without hiding
      // the board.
      return (tint: const Color(0xFF0A1230), strength: 0.42);
    }
    if (elevation <= 0) {
      // Twilight: night fading up through indigo.
      final t = (elevation + 12) / 12;
      return (
        tint: Color.lerp(
            const Color(0xFF0A1230), const Color(0xFF2A2350), t)!,
        strength: 0.42 - 0.10 * t,
      );
    }
    if (elevation <= 8) {
      // The golden hour, and the only time the board goes properly warm.
      final t = elevation / 8;
      return (
        tint: Color.lerp(
            const Color(0xFFFF9A4D), const Color(0xFFFFD9A0), t)!,
        strength: 0.30 * (1 - t * 0.55),
      );
    }
    // Daylight: almost nothing, warming very slightly toward the horizon.
    final t = ((elevation - 8) / 45).clamp(0.0, 1.0);
    return (
      tint: const Color(0xFFFFF2D8),
      strength: 0.13 * (1 - t),
    );
  }

  @override
  void render(Canvas canvas) {
    final elevation = game.sun.elevationDegrees;
    final grade = gradeFor(elevation);
    final full = Rect.fromLTWH(0, 0, game.size.x, game.size.y);

    // A vertical gradient rather than a flat fill: the horizon carries more of
    // the light than the ground does, which is what stops a tinted board from
    // looking like a colour filter.
    canvas.drawRect(
      full,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, 0),
          Offset(0, game.size.y),
          [
            grade.tint.withValues(alpha: grade.strength * 1.25),
            grade.tint.withValues(alpha: grade.strength * 0.65),
          ],
        ),
    );

    // Around sunrise and sunset, a band of warm light low on the screen, on the
    // side the sun is actually on.
    if (elevation > -6 && elevation < 12) {
      final warmth = (1 - (elevation.abs() / 12)).clamp(0.0, 1.0);
      final morning = game.timeOfDay < 0.5;
      final cx = morning ? game.size.x * 0.18 : game.size.x * 0.82;
      canvas.drawRect(
        full,
        Paint()
          ..shader = Gradient.radial(
            Offset(cx, game.size.y * 0.28),
            game.size.x * 0.9,
            [
              const Color(0xFFFFB25E).withValues(alpha: 0.30 * warmth),
              const Color(0x00FFB25E),
            ],
          ),
      );
    }
  }
}

/// Where the sun is throwing shadows, and how long they are.
///
/// Shadows are the cheapest thing that makes a flat board look like a place,
/// and here they are not decoration: they lengthen through the afternoon and
/// swing across the site exactly as the real sun moves, so the player can read
/// the time of day off the ground without looking at a clock.
class SunShadow {
  /// Offset in screen pixels for a structure of [height] pixels, or null when
  /// the sun is down.
  static Offset? offsetFor({
    required double elevationDegrees,
    required double timeOfDay,
    required double height,
  }) {
    if (elevationDegrees <= 1) return null;
    // Long at the horizon, short at noon; capped so dawn does not throw a
    // shadow across the whole map.
    final length =
        (height / math.tan(elevationDegrees * math.pi / 180)).clamp(0.0, height * 4);
    // The sun tracks east to west, so shadows swing the other way.
    final dir = (timeOfDay - 0.5) * 2; // -1 morning, +1 evening
    return Offset(-dir * length, length * 0.32);
  }

  /// How dark a shadow is: sharpest when the sun is high.
  static double opacityFor(double elevationDegrees) {
    if (elevationDegrees <= 1) return 0;
    return (0.10 + elevationDegrees / 90 * 0.22).clamp(0.0, 0.32);
  }
}
