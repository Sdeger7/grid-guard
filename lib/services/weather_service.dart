import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A real observation for a real place.
@immutable
class LiveWeather {
  const LiveWeather({
    required this.cloudCover,
    required this.windSpeed,
    required this.temperature,
    required this.fetchedAtMs,
    required this.cityId,
  });

  /// Cloud cover 0..1 — what actually decides how much of the sun reaches a
  /// panel today.
  final double cloudCover;

  /// Wind speed in m/s at 10m.
  final double windSpeed;

  final double temperature;
  final int fetchedAtMs;
  final String cityId;

  /// Multiplier on clear-sky solar output. Heavy cloud costs roughly three
  /// quarters of it, which is about right for real panels.
  double get solarScale => (1.0 - 0.75 * cloudCover).clamp(0.15, 1.0);

  /// Turbines idle below their cut-in speed, climb steeply through the middle
  /// of the range, and are held at rated output above it.
  double get windScale {
    if (windSpeed < 3) return 0.1;
    if (windSpeed >= 12) return 1.6;
    return (0.1 + (windSpeed - 3) / 9 * 1.5).clamp(0.1, 1.6);
  }

  String get summary {
    if (cloudCover > 0.75) return 'Overcast';
    if (cloudCover > 0.4) return 'Cloudy';
    if (windSpeed > 10) return 'Blustery';
    if (temperature > 30) return 'Hot';
    return 'Clear';
  }

  String get emoji {
    if (cloudCover > 0.75) return '☁️';
    if (cloudCover > 0.4) return '⛅';
    if (windSpeed > 10) return '🌬️';
    if (temperature > 30) return '🔥';
    return '☀️';
  }

  Map<String, dynamic> toJson() => {
        'cloud': cloudCover,
        'wind': windSpeed,
        'temp': temperature,
        'at': fetchedAtMs,
        'city': cityId,
      };

  static LiveWeather fromJson(Map<String, dynamic> j) => LiveWeather(
        cloudCover: (j['cloud'] as num).toDouble(),
        windSpeed: (j['wind'] as num).toDouble(),
        temperature: (j['temp'] as num).toDouble(),
        fetchedAtMs: (j['at'] as num).toInt(),
        cityId: j['city'] as String,
      );
}

/// Fetches the weather actually happening over the site.
///
/// A game about solar generation that invents its own cloud cover is telling a
/// story; one that reads the sky over Konya is running a simulation. Open-Meteo
/// needs no key and permits this use, and everything is cached — the game stays
/// fully playable offline, falling back to its own weather model when there is
/// no network or the cache has gone stale.
class WeatherService {
  WeatherService(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'grid_guard.weather.v1';

  /// Refetch at most this often; conditions do not move faster than this and
  /// the free service should not be hammered.
  static const Duration refreshInterval = Duration(minutes: 30);

  LiveWeather? _cached;

  /// The last observation, from memory or disk. Null on a first run offline.
  LiveWeather? get cached {
    if (_cached != null) return _cached;
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return _cached = LiveWeather.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  bool _isFresh(LiveWeather w, String cityId) =>
      w.cityId == cityId &&
      DateTime.now().millisecondsSinceEpoch - w.fetchedAtMs <
          refreshInterval.inMilliseconds;

  /// Returns current conditions for a site, fetching only when the cache is
  /// stale or belongs to another city. Never throws: on any failure the caller
  /// simply keeps whatever it had, or falls back to simulated weather.
  Future<LiveWeather?> conditionsFor({
    required String cityId,
    required double latitude,
    required double longitude,
  }) async {
    final have = cached;
    if (have != null && _isFresh(have, cityId)) return have;

    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${latitude.toStringAsFixed(3)}'
        '&longitude=${longitude.toStringAsFixed(3)}'
        '&current=cloud_cover,wind_speed_10m,temperature_2m'
        '&wind_speed_unit=ms',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return have;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final current = body['current'] as Map<String, dynamic>?;
      if (current == null) return have;

      final fresh = LiveWeather(
        cloudCover: ((current['cloud_cover'] as num?)?.toDouble() ?? 0) / 100.0,
        windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
        temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 15,
        fetchedAtMs: DateTime.now().millisecondsSinceEpoch,
        cityId: cityId,
      );
      _cached = fresh;
      await _prefs.setString(_key, jsonEncode(fresh.toJson()));
      return fresh;
    } catch (_) {
      // Offline, blocked, slow, malformed — all the same answer: keep playing
      // with what we have.
      return have;
    }
  }
}
