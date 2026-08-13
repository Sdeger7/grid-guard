import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One result on a weekly challenge board.
@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.week,
    required this.name,
    required this.score,
    required this.city,
    required this.days,
    this.isYou = false,
  });

  final int week;
  final String name;
  final int score;
  final String city;
  final int days;
  final bool isYou;

  Map<String, dynamic> toJson() => {
        'w': week,
        'n': name,
        's': score,
        'c': city,
        'd': days,
      };

  static LeaderboardEntry fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        week: (j['w'] as num).toInt(),
        name: j['n'] as String,
        score: (j['s'] as num).toInt(),
        city: j['c'] as String,
        days: (j['d'] as num?)?.toInt() ?? 0,
        isYou: true,
      );
}

/// Where challenge results go.
///
/// The interface is the point. Today the only implementation keeps results on
/// the device, so the challenge works with no account, no network and no
/// backend bill. When a server is worth having, a second implementation of
/// exactly these three methods is the whole change — nothing that calls this
/// has to know which one it is talking to.
///
/// The server-side shape it is written against, for whenever that happens:
///
///   create table gg_scores (
///     id          bigserial primary key,
///     week        int not null,
///     player_id   uuid not null,
///     name        text not null,
///     score       bigint not null,
///     city        text not null,
///     days        int not null,
///     created_at  timestamptz default now(),
///     unique (week, player_id)
///   );
///   -- read-only to everyone, writable only as yourself
///   alter table gg_scores enable row level security;
///
abstract class LeaderboardService {
  /// Records a result for a week. Keeps the best per player.
  Future<void> submit(LeaderboardEntry entry);

  /// The board for a week, best first.
  Future<List<LeaderboardEntry>> top(int week, {int limit = 25});

  /// Every week this player has a result for, most recent first.
  Future<List<LeaderboardEntry>> history();
}

/// Results kept on the device.
///
/// This is not a placeholder to be embarrassed about: a personal history of
/// weeks played, with the best score on each, is most of what a leaderboard is
/// for. Comparing against other people happens through the result card, which
/// works anywhere and needs nobody's servers.
class LocalLeaderboard implements LeaderboardService {
  LocalLeaderboard(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'grid_guard.leaderboard.v1';

  List<LeaderboardEntry> _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<LeaderboardEntry> list) async {
    await _prefs.setString(
        _key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  @override
  Future<void> submit(LeaderboardEntry entry) async {
    final list = _load();
    final i = list.indexWhere((e) => e.week == entry.week);
    if (i < 0) {
      list.add(entry);
    } else if (entry.score > list[i].score) {
      list[i] = entry;
    } else {
      return;
    }
    list.sort((a, b) => b.week.compareTo(a.week));
    await _save(list);
  }

  @override
  Future<List<LeaderboardEntry>> top(int week, {int limit = 25}) async =>
      _load().where((e) => e.week == week).toList();

  @override
  Future<List<LeaderboardEntry>> history() async => _load();
}
