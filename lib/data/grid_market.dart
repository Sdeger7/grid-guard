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

    return (basePrice * demand / math.max(0.35, supply) * drift)
        .clamp(0.12, 3.2);
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

  /// A short label for the HUD: cheap / fair / dear, so the player can read the
  /// market at a glance without doing arithmetic.
  static String bandFor(double price) {
    if (price < 0.35) return 'CHEAP';
    if (price < 0.85) return 'FAIR';
    if (price < 1.6) return 'HIGH';
    return 'PEAK';
  }
}
