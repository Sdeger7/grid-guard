import 'dart:math' as math;

/// The WATT issuance schedule.
///
/// There will only ever be 2,500,000 WATT. Everything the currency is worth
/// rests on that: perks, cosmetics and tournament pools are all priced against
/// a supply that cannot be expanded, and a game that can print more of its own
/// currency has, in the end, no currency at all.
///
/// Issuance halves on a fixed calendar, the way mining rewards do. Early
/// players mine faster than late ones, the curve flattens toward the cap and
/// never reaches it — and because the schedule is a pure function of the date,
/// every client agrees on it without asking anyone.
class WattSupply {
  /// The hard cap. Nothing may mint past it.
  static const double maxSupply = 2500000;

  /// When issuance began.
  static final DateTime genesis = DateTime.utc(2026, 1, 1);

  /// How long a halving epoch runs.
  static const int halvingDays = 180;

  /// Which epoch a date falls in.
  static int epochAt([DateTime? when]) {
    final days = (when ?? DateTime.now()).toUtc().difference(genesis).inDays;
    if (days <= 0) return 0;
    return days ~/ halvingDays;
  }

  /// The issuance multiplier now: full rate in the first epoch, half in the
  /// second, and so on. Floored so mining never stops outright — it simply
  /// becomes slow enough that the cap is approached and never crossed.
  static double emissionMultiplier([DateTime? when]) {
    final e = epochAt(when);
    return math.max(0.03125, math.pow(0.5, e).toDouble());
  }

  /// Days until the next halving, for the UI to count down.
  static int daysToNextHalving([DateTime? when]) {
    final now = (when ?? DateTime.now()).toUtc();
    final days = now.difference(genesis).inDays;
    if (days < 0) return -days;
    return halvingDays - (days % halvingDays);
  }

  /// Roughly how much of the cap has been issued by now.
  ///
  /// Without a server there is no census of what everyone has mined, so this is
  /// the schedule's own projection rather than a measurement: what the curve
  /// says should exist by this date. It is honest about being an estimate
  /// wherever it is shown.
  static double projectedIssued([DateTime? when]) {
    final e = epochAt(when);
    // Each epoch issues half the previous one, so the series converges: the
    // first epoch accounts for half of everything that will ever exist.
    var issued = 0.0;
    var share = 0.5;
    for (var i = 0; i < e; i++) {
      issued += share;
      share /= 2;
    }
    // Partial progress through the current epoch.
    final into = halvingDays - daysToNextHalving(when);
    issued += share * (into / halvingDays);
    return (issued * maxSupply).clamp(0, maxSupply);
  }

  static double get remaining => maxSupply - projectedIssued();
}

/// The treasury.
///
/// WATT is capped, so it cannot simply be conjured for rewards and it should
/// not be destroyed either. What a tournament does not pay out — the share
/// above the places — returns here, and streak milestones, mission bonuses and
/// future events are paid from it. Nothing enters or leaves the world: the same
/// WATT circulates between players and the treasury forever.
///
/// Keeping the rake rather than burning it is the better design. A burn makes
/// the currency scarcer at the cost of steadily emptying the game of it; a
/// treasury lets the same supply fund every reward the game will ever hand out,
/// which is what a fixed cap needs in order to be livable.
class WattTreasury {
  /// The share of a prize pool that is not paid to the places.
  static const double rakeShare = 0.14;

  /// What a pool of this size returns to the treasury.
  static double rakeFrom(double pool) => pool * rakeShare;
}
