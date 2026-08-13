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

  /// How hard mining is right now, expressed as the fraction of the base rate
  /// a rig actually produces.
  ///
  /// This is the mechanism that makes the cap real rather than a promise.
  /// Difficulty is a function of how much of the supply has already been
  /// issued: the emptier the remaining reserve, the slower everything mines.
  /// Because the rate falls with what is left, the total issued approaches
  /// 2,500,000 asymptotically and cannot cross it — no clamp, no special case,
  /// no way to game it. Early operators mine at nearly full speed; late ones
  /// work for hundredths of the same.
  ///
  /// The exponent decides how sharply it bites. Above one, difficulty rises
  /// faster than the reserve empties, which front-loads the curve the way real
  /// mining rewards are front-loaded.
  static const double difficultyExponent = 1.6;

  /// Floor, so mining never becomes literally impossible — only vanishingly
  /// slow, which is what "capped" means in practice.
  static const double minimumRate = 0.005;

  static double emissionMultiplier([DateTime? when]) {
    final left = (remainingAt(when) / maxSupply).clamp(0.0, 1.0);
    return math.max(minimumRate, math.pow(left, difficultyExponent).toDouble());
  }

  /// Mining difficulty as a multiple of launch-day difficulty, which is the
  /// number worth showing a player.
  static double difficultyAt([DateTime? when]) {
    final rate = emissionMultiplier(when);
    return rate <= 0 ? double.infinity : 1 / rate;
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

  static double remainingAt([DateTime? when]) =>
      maxSupply - projectedIssued(when);

  static double get remaining => remainingAt();

  /// Share of the cap already in circulation, 0..1.
  static double issuedFraction([DateTime? when]) =>
      (projectedIssued(when) / maxSupply).clamp(0.0, 1.0);
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
