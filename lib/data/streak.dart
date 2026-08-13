import 'package:flutter/foundation.dart';

/// One day's reward on the login streak.
@immutable
class StreakReward {
  const StreakReward({
    required this.day,
    required this.cash,
    this.watt = 0,
    this.skinId,
    this.label,
  });

  /// Which consecutive day this pays out on.
  final int day;

  final int cash;

  /// WATT is the rarest thing in the game, so streak milestones are one of the
  /// very few places it is given rather than mined — and only at the far end.
  final double watt;

  /// A cosmetic unlocked at a milestone.
  final String? skinId;

  final String? label;
}

/// The escalating daily reward.
///
/// The mechanic that moves retention numbers more than any other is simple and
/// slightly cruel: rewards climb while you keep showing up, and miss a day and
/// you start again at day one. Milestones at 7, 14 and 30 give the streak
/// somewhere to be heading.
class StreakCalendar {
  static const int cycle = 30;

  static StreakReward rewardFor(int day) {
    final d = day.clamp(1, cycle);
    switch (d) {
      case 7:
        return const StreakReward(
            day: 7,
            cash: 2500,
            watt: 0.25,
            label: 'One week — a quarter WATT');
      case 14:
        return const StreakReward(
            day: 14,
            cash: 8000,
            watt: 0.75,
            skinId: 'drone_hazard',
            label: 'Two weeks — Hazard Stripe drones');
      case 30:
        return const StreakReward(
            day: 30,
            cash: 30000,
            watt: 3,
            skinId: 'struct_carbon',
            label: 'A month — Carbon Works');
      default:
        // Everything between milestones pays cash that grows with the streak.
        return StreakReward(day: d, cash: 250 + d * 180);
    }
  }

  /// Whole local days since the epoch — the unit a streak is counted in.
  static int today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
            .millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
  }
}
