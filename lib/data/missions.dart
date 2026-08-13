import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// What a mission measures. Each maps to a counter the game already keeps, so
/// missions never need their own bookkeeping in the game loop.
enum MissionMetric {
  /// Raiders shot down since the day began.
  kills,

  /// Structures built since the day began.
  builds,

  /// Upgrades bought since the day began.
  upgrades,

  /// Repairs paid for since the day began.
  repairs,

  /// Nights survived without a blackout, counted from the day the mission was
  /// issued.
  nightsHeld,
}

/// A daily objective. Missions are the small, always-reachable goal that gives
/// a session a point beyond "watch the meter go up", and they pay in WATT —
/// the currency that buys permanent perks.
@immutable
class Mission {
  const Mission({
    required this.metric,
    required this.target,
    required this.reward,
    required this.title,
  });

  final MissionMetric metric;
  final int target;

  /// WATT paid on completion.
  final double reward;

  final String title;
}

class MissionCatalog {
  /// Three missions for [day], scaled so they stay meaningful as the site
  /// grows. Deterministic per day, so closing and reopening the app doesn't
  /// reroll a mission the player already part-finished.
  static List<Mission> forDay(int day) {
    final r = math.Random(day * 6733 + 17);
    final pool = <Mission>[
      Mission(
        metric: MissionMetric.kills,
        target: 8 + day * 2,
        reward: 1.0 + day * 0.1,
        title: 'Shoot down ${8 + day * 2} raiders',
      ),
      Mission(
        metric: MissionMetric.builds,
        target: 2 + (day ~/ 4),
        reward: 0.8 + day * 0.08,
        title: 'Build ${2 + (day ~/ 4)} new units',
      ),
      Mission(
        metric: MissionMetric.upgrades,
        target: 1 + (day ~/ 5),
        reward: 1.2 + day * 0.1,
        title: 'Buy ${1 + (day ~/ 5)} upgrades',
      ),
      Mission(
        metric: MissionMetric.repairs,
        target: 2 + (day ~/ 3),
        reward: 0.7 + day * 0.07,
        title: 'Repair ${2 + (day ~/ 3)} structures',
      ),
      const Mission(
        metric: MissionMetric.nightsHeld,
        target: 1,
        reward: 1.5,
        title: 'Hold tonight without a blackout',
      ),
    ];
    pool.shuffle(r);
    // The night-hold mission is the anchor: always offer it, plus two others.
    final picked = <Mission>[pool.firstWhere(
        (m) => m.metric == MissionMetric.nightsHeld)];
    for (final m in pool) {
      if (picked.length >= 3) break;
      if (m.metric == MissionMetric.nightsHeld) continue;
      picked.add(m);
    }
    return picked;
  }
}
