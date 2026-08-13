import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// The day's weather. Rolled fresh each dawn, it swings the two things the grid
/// actually lives on — sunlight and wind — so no two days play identically and
/// a storm day is a real planning problem rather than a colour change.
@immutable
class Weather {
  const Weather({
    required this.id,
    required this.name,
    required this.emoji,
    required this.sunScale,
    required this.windScale,
    required this.raiderSpeedScale,
    required this.note,
  });

  final String id;
  final String name;
  final String emoji;

  /// Multiplies solar output for the day.
  final double sunScale;

  /// Multiplies wind output for the day.
  final double windScale;

  /// Raiders fly slower in bad air, which is the one mercy of a storm.
  final double raiderSpeedScale;

  final String note;
}

class WeatherCatalog {
  static const clear = Weather(
    id: 'clear',
    name: 'Clear',
    emoji: '☀️',
    sunScale: 1.0,
    windScale: 0.9,
    raiderSpeedScale: 1.0,
    note: 'Full sun, light air. Solar carries the day.',
  );

  static const List<Weather> all = [
    clear,
    Weather(
      id: 'breezy',
      name: 'Breezy',
      emoji: '🌤️',
      sunScale: 0.9,
      windScale: 1.35,
      raiderSpeedScale: 1.0,
      note: 'Turbines run hard; panels lose a little to haze.',
    ),
    Weather(
      id: 'overcast',
      name: 'Overcast',
      emoji: '☁️',
      sunScale: 0.45,
      windScale: 1.1,
      raiderSpeedScale: 1.0,
      note: 'Panels are half-blind. Lean on wind and the battery.',
    ),
    Weather(
      id: 'storm',
      name: 'Storm',
      emoji: '⛈️',
      sunScale: 0.2,
      windScale: 1.6,
      raiderSpeedScale: 0.8,
      note: 'Almost no sun, huge wind, and raiders fly badly.',
    ),
    Weather(
      id: 'heatwave',
      name: 'Heatwave',
      emoji: '🔥',
      sunScale: 1.25,
      windScale: 0.45,
      raiderSpeedScale: 1.1,
      note: 'Peak solar, dead air — and everything moves faster.',
    ),
  ];

  /// Picks the weather for [day]. Deterministic, so a saved site reloads into
  /// the same forecast it was showing.
  static Weather forDay(int day) {
    if (day <= 1) return clear; // never open a new site on a storm
    final r = math.Random(day * 7717 + 91);
    final roll = r.nextDouble();
    if (roll < 0.34) return all[0]; // clear
    if (roll < 0.58) return all[1]; // breezy
    if (roll < 0.78) return all[2]; // overcast
    if (roll < 0.92) return all[3]; // storm
    return all[4]; // heatwave
  }
}
