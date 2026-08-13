import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// The weekly challenge.
///
/// A permanent site is a marathon nobody can be compared on: whoever started
/// first is ahead, and a new player looking at someone's month-old operation
/// learns only that they are behind. The challenge is the other race — everyone
/// gets the identical seed, the identical weather, the identical raid calendar
/// and the same seed capital, for seven in-game days. What separates two
/// results is the decisions, and that is the only kind of score worth comparing.
@immutable
class WeeklyChallenge {
  const WeeklyChallenge({
    required this.week,
    required this.seed,
    required this.cityIndex,
    required this.startMoney,
    required this.days,
    required this.name,
    required this.blurb,
  });

  /// Weeks since the epoch Monday — the challenge id, and what players compare.
  final int week;

  /// Drives weather, raids and prices identically for every player.
  final int seed;

  /// Which province everyone runs the week in.
  final int cityIndex;
  final int startMoney;
  final int days;
  final String name;
  final String blurb;
}

class ChallengeCatalog {
  static const List<(String, String)> _briefs = [
    ('Cold Start', 'Modest capital, ordinary ground. Everything you build, '
        'you paid for.'),
    ('Windfall', 'A coastal week. The turbines will carry you if you build '
        'for them.'),
    ('Hard Sun', 'Ash basin conditions. Enormous days, dead nights, and '
        'storage is everything.'),
    ('Under Fire', 'The zone is being cleared out. Defend first, earn second.'),
    ('Thin Margins', 'Half the usual capital. Every purchase has to pay for '
        'itself.'),
  ];

  /// The challenge running now. Weeks turn over on Monday, in UTC, so every
  /// player is inside the same one at the same time.
  static WeeklyChallenge current([DateTime? now]) {
    final week = weekNumber(now ?? DateTime.now());
    final brief = _briefs[week % _briefs.length];
    return WeeklyChallenge(
      week: week,
      seed: week * 7919 + 13,
      // The zone rotates so a run is never the same shape twice.
      cityIndex: week % 6,
      startMoney: week % _briefs.length == 4 ? 210 : 420,
      days: 7,
      name: brief.$1,
      blurb: brief.$2,
    );
  }

  static int weekNumber(DateTime now) {
    final start = DateTime.utc(2026, 1, 5); // a Monday
    return (now.toUtc().difference(start).inDays / 7).floor();
  }

  /// When the current challenge closes.
  static DateTime endOfWeek([DateTime? now]) {
    final t = (now ?? DateTime.now()).toUtc();
    final monday = DateTime.utc(t.year, t.month, t.day)
        .subtract(Duration(days: t.weekday - 1));
    return monday.add(const Duration(days: 7));
  }

  // ---- Entry stakes ----
  //
  // Entering costs WATT, and the run either returns more than went in or none
  // of it. That only stays lawful because WATT cannot be bought at any price:
  // it is earned in-game and spent in-game, which keeps this a skill contest
  // in a closed currency rather than a wager on money. If WATT is ever made
  // purchasable, this mechanic has to go with it.
  //
  // Without a server there is no pool of other players to win from, so a run
  // is measured against par: a target derived from the same seed everyone
  // else gets, scaled by the stake. Beating it pays; missing it does not. When
  // a server exists, par becomes the field's median and the payout becomes the
  // pool — the shape does not change.

  /// The stakes a player may enter at, in WATT.
  static const List<double> stakes = [0.05, 0.20, 1.00];

  /// The score to beat at a given stake. Bigger stakes ask for more, so the
  /// high table is not simply a bigger bet on the same run.
  static int parFor(WeeklyChallenge c, double stake) {
    final r = math.Random(c.seed);
    final base = 24000 + r.nextInt(9000);
    final multiplier = stake <= 0.05
        ? 1.0
        : stake <= 0.2
            ? 1.9
            : 3.4;
    return (base * multiplier).round();
  }

  /// What a finished run returns, in WATT.
  ///
  /// Missing par loses the stake outright; landing just under it is refunded,
  /// because a run that came close should not feel like a mugging; beating it
  /// pays, and beating it convincingly pays properly.
  static double payoutFor({
    required double stake,
    required int score,
    required int par,
  }) {
    if (par <= 0) return stake;
    final ratio = score / par;
    if (ratio >= 1.5) return stake * 3.0;
    if (ratio >= 1.0) return stake * 1.8;
    if (ratio >= 0.9) return stake;
    return 0;
  }

  /// A score worth ranking: what the site is worth, weighted by how cleanly it
  /// was held. Blackouts hurt because surviving intact is the actual skill.
  static int scoreFor({
    required int baseValue,
    required int money,
    required int blackouts,
    required double watt,
  }) {
    final gross = baseValue + money + (watt * 4000).round();
    final penalty = 1.0 - (blackouts * 0.15).clamp(0.0, 0.6);
    return (gross * penalty).round();
  }
}
