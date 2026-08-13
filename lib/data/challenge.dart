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
    required this.zoneIndex,
    required this.startMoney,
    required this.days,
    required this.name,
    required this.blurb,
  });

  /// Weeks since the epoch Monday — the challenge id, and what players compare.
  final int week;

  /// Drives weather, raids and prices identically for every player.
  final int seed;

  final int zoneIndex;
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
      zoneIndex: week % 4,
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
