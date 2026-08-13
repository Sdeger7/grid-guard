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

  // ---- Entry and prize pool ----
  //
  // A week is a tournament: everyone pays the same entry into a pool, and the
  // pool is paid back out by finishing position. Nothing is taken from anyone
  // who does not choose to enter, and the entry is WATT — earned in-game,
  // spendable only in-game, and never purchasable — so the pool is an internal
  // economy, not a market in anything.
  //
  // Part of the pool is not paid back. That is deliberate: WATT is minted
  // continuously by mining, and a competition that returns less than it takes
  // is the one place the economy removes any, which is what keeps it worth
  // something over years rather than inflating away.

  /// What it costs to enter a week.
  static const double entryFee = 0.10;

  /// The share of the pool paid to each finishing position.
  ///
  /// Top-heavy enough that winning matters, wide enough that a good week
  /// outside the podium is still worth entering.
  static double poolShareForRank(int rank, int field) {
    if (rank <= 0 || rank > field) return 0;
    if (rank == 1) return 0.25;
    if (rank == 2) return 0.15;
    if (rank == 3) return 0.10;
    if (rank <= 10) return 0.03; // 7 places, 21%
    if (rank <= 20) return 0.015; // 10 places, 15%
    return 0;
  }

  /// What a finishing position pays out of a pool of [field] entries.
  static double prizeFor({required int rank, required int field}) =>
      field * entryFee * poolShareForRank(rank, field);

  /// This week's field, until real entries exist.
  ///
  /// These are benchmark runs, not people: scores generated from the same seed
  /// the week itself uses, so the ladder is identical for everyone and a
  /// position means the same thing to two different players. When entries are
  /// real, this is the function that gets replaced and nothing else.
  static List<int> benchmarkField(WeeklyChallenge c, {int size = 60}) {
    final r = math.Random(c.seed * 31 + 7);
    final target = targetFor(c);
    final scores = <int>[];
    for (var i = 0; i < size; i++) {
      // A long tail of ordinary runs and a thin top end, which is what a real
      // ladder looks like.
      final skill = math.pow(r.nextDouble(), 2.2).toDouble();
      scores.add((target * (0.35 + skill * 1.6)).round());
    }
    scores.sort((a, b) => b.compareTo(a));
    return scores;
  }

  /// Where a score would place in the field.
  static int rankOf(int score, List<int> field) {
    var rank = 1;
    for (final s in field) {
      if (s > score) rank++;
    }
    return rank;
  }

  /// The reference score for a week — what a solid run of it looks like.
  static int targetFor(WeeklyChallenge c) {
    final r = math.Random(c.seed);
    return 24000 + r.nextInt(9000);
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
