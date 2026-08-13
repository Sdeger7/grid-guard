import 'package:flutter/foundation.dart';

/// A scheduled world event.
///
/// Idle games are kept alive by a calendar, not by a meter: the reason to open
/// the app is that something is happening *now*, not that something accrued.
/// Events run on real-world days so every player is inside the same one at the
/// same time, which is also what makes them worth talking about.
@immutable
class WorldEvent {
  const WorldEvent({
    required this.id,
    required this.name,
    required this.emoji,
    required this.blurb,
    this.priceScale = 1.0,
    this.threatScale = 1.0,
    this.miningScale = 1.0,
    this.incomeScale = 1.0,
    this.sunScale = 1.0,
    this.windScale = 1.0,
  });

  final String id;
  final String name;
  final String emoji;
  final String blurb;

  /// Multipliers applied on top of everything else for the event's duration.
  final double priceScale;
  final double threatScale;
  final double miningScale;
  final double incomeScale;
  final double sunScale;
  final double windScale;

  bool get isQuiet => id == 'none';
}

class EventCalendar {
  static const none = WorldEvent(
    id: 'none',
    name: 'Nothing scheduled',
    emoji: '·',
    blurb: 'An ordinary week on the grid.',
  );

  static const List<WorldEvent> events = [
    WorldEvent(
      id: 'drought',
      name: 'Drought Week',
      emoji: '🥵',
      blurb: 'The hydro plants are dry and the whole zone is short. Power '
          'prices double — a good week to be selling, a brutal one to be '
          'buying.',
      priceScale: 2.0,
      sunScale: 1.15,
      windScale: 0.8,
    ),
    WorldEvent(
      id: 'blackout',
      name: 'Regional Blackout',
      emoji: '🕯️',
      blurb: 'The public grid is down. Nothing to buy at any price, and every '
          'contract pays a premium to whoever can still deliver.',
      priceScale: 3.0,
      incomeScale: 1.4,
      threatScale: 1.2,
    ),
    WorldEvent(
      id: 'gale',
      name: 'Gale Season',
      emoji: '🌬️',
      blurb: 'A week of hard weather. Turbines run flat out, panels see very '
          'little, and raiders fly badly in it.',
      windScale: 1.8,
      sunScale: 0.6,
      threatScale: 0.85,
    ),
    WorldEvent(
      id: 'crackdown',
      name: 'Crackdown',
      emoji: '🚁',
      blurb: 'Somebody upstairs wants the independents gone. Raids come '
          'harder all week — and every contract pays hazard rates.',
      threatScale: 1.6,
      incomeScale: 1.5,
    ),
    WorldEvent(
      id: 'boom',
      name: 'Compute Boom',
      emoji: '📈',
      blurb: 'Demand for compute goes vertical. Contracts pay half again, and '
          'mining rigs run hot.',
      incomeScale: 1.5,
      miningScale: 1.5,
      threatScale: 1.15,
    ),
    WorldEvent(
      id: 'glut',
      name: 'Solar Glut',
      emoji: '☀️',
      blurb: 'Every site in the region is dumping power at once. Prices fall '
          'through the floor: fill your batteries, sell nothing.',
      priceScale: 0.4,
      sunScale: 1.3,
    ),
  ];

  /// The event running on [now]. Events run Monday to Sunday and there is a
  /// quiet week in the rotation, so an event landing actually feels like news.
  static WorldEvent current(DateTime now) {
    final week = _weekNumber(now);
    // Every fourth week is quiet.
    if (week % 4 == 3) return none;
    return events[week % events.length];
  }

  /// When the current week ends, so the UI can count down to the next one.
  static DateTime endOfWeek(DateTime now) {
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return monday.add(const Duration(days: 7));
  }

  static int _weekNumber(DateTime now) {
    final start = DateTime.utc(2026, 1, 5); // a Monday
    return (now.toUtc().difference(start).inDays / 7).floor();
  }
}
