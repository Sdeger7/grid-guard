import 'dart:math' as math;

import 'weather.dart';

/// The public electricity market.
///
/// Today this is a simulated price curve: cheap at midday when every solar site
/// in the zone is dumping power, expensive at dusk and through the night when
/// nothing is generating and everyone is drawing. That is the real shape of a
/// solar-heavy grid — the duck curve — and it makes storage the whole game:
/// charge when power is worthless, sell or self-consume when it is dear.
///
/// It is written as one pure function of time, weather and day so it can later
/// be replaced by a live order book: when players can sell their surplus to
/// each other, [priceAt] simply reads the last cleared trade instead of this
/// curve, and nothing else in the game has to change.
class GridMarket {
  /// Baseline price in MONEY per unit of energy.
  static const double basePrice = 0.55;

  /// The utility's cut. Buying always costs more than selling pays — the spread
  /// is what makes an oversized battery worth building.
  static const double sellFraction = 0.55;

  /// Import price right now, in MONEY per unit of energy.
  ///
  /// [timeOfDay] is the game clock in [0,1) (0.5 = noon). [sunFactor] is how
  /// much sun the zone is getting, which stands in for how much cheap solar the
  /// rest of the grid is producing.
  static double priceAt({
    required double timeOfDay,
    required double sunFactor,
    required Weather weather,
    required int day,
  }) {
    // Demand curve: two peaks, morning and evening, trough overnight.
    final morning = math.exp(-math.pow((timeOfDay - 0.32) / 0.06, 2));
    final evening = math.exp(-math.pow((timeOfDay - 0.80) / 0.07, 2));
    final demand = 0.75 + 0.55 * evening + 0.30 * morning;

    // Supply: the more sun the zone gets, the more the grid is flooded with
    // cheap solar. Weather moves this for everyone, not just the player.
    final supply = 0.55 + 0.95 * sunFactor * weather.sunScale +
        0.25 * (weather.windScale - 1.0);

    // A slow, deterministic drift so no two days price the same.
    final drift = 1.0 + 0.12 * math.sin(day * 1.7);

    final peak = isPeakNow() ? peakMultiplier : 1.0;
    return (basePrice * demand / math.max(0.35, supply) * drift * peak)
        .clamp(0.12, 9.0);
  }

  /// What the grid pays for a unit you export.
  static double exportPriceAt({
    required double timeOfDay,
    required double sunFactor,
    required Weather weather,
    required int day,
  }) =>
      priceAt(
        timeOfDay: timeOfDay,
        sunFactor: sunFactor,
        weather: weather,
        day: day,
      ) *
      sellFraction;

  /// The evening demand peak, in local wall-clock hours.
  ///
  /// The game clock runs at one in-game hour per real minute, which makes the
  /// in-game price cycle far too fast to build a habit around. This window is
  /// pinned to the player's actual evening instead: for two real hours, power
  /// trades at a large premium. It is the one thing in the game you can only
  /// have by being here at a particular time, and missing it costs nothing but
  /// the opportunity — which is exactly the shape that brings people back.
  static const int peakStartHour = 19;
  static const int peakEndHour = 21;
  static const double peakMultiplier = 2.6;

  static bool isPeakNow([DateTime? now]) {
    final h = (now ?? DateTime.now()).hour;
    return h >= peakStartHour && h < peakEndHour;
  }

  /// Minutes until the peak opens, or until it closes if it is running.
  static int minutesToPeakEdge([DateTime? now]) {
    final t = now ?? DateTime.now();
    final target = isPeakNow(t) ? peakEndHour : peakStartHour;
    var diff = (target - t.hour) * 60 - t.minute;
    if (diff <= 0) diff += 24 * 60;
    return diff;
  }

  /// A short label for the HUD: cheap / fair / dear, so the player can read the
  /// market at a glance without doing arithmetic.
  static String bandFor(double price) {
    if (price < 0.35) return 'CHEAP';
    if (price < 0.85) return 'FAIR';
    if (price < 1.6) return 'HIGH';
    return 'PEAK';
  }
}
