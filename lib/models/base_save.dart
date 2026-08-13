import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'land_holding.dart';
import 'tower_type.dart';

/// One placed structure, as stored on disk.
@immutable
class SavedStructure {
  const SavedStructure({
    required this.type,
    required this.col,
    required this.row,
    required this.tier,
    required this.healthFraction,
  });

  final TowerType type;
  final int col;
  final int row;
  final int tier;

  /// Damage carries across sessions — you come back to the base you left,
  /// dents and all.
  final double healthFraction;

  Map<String, dynamic> toJson() => {
        't': type.name,
        'c': col,
        'r': row,
        'k': tier,
        'h': healthFraction,
      };

  static SavedStructure? fromJson(Map<String, dynamic> j) {
    final name = j['t'] as String?;
    final type = TowerType.values.where((t) => t.name == name).firstOrNull;
    if (type == null) return null; // Structure removed from the game since.
    return SavedStructure(
      type: type,
      col: (j['c'] as num).toInt(),
      row: (j['r'] as num).toInt(),
      tier: (j['k'] as num).toInt(),
      healthFraction: ((j['h'] as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0),
    );
  }
}

/// The persistent base: everything needed to put the player back exactly where
/// they left off, plus the timestamp that lets the game work out what the site
/// earned while the app was closed.
@immutable
class BaseSave {
  const BaseSave({
    required this.structures,
    this.money = 0,
    this.coins = 0,
    this.energy = 0,
    this.dayNumber = 1,
    this.timeOfDay = 0.28,
    this.workloadIndex = 0,
    this.zoneIndex = 0,
    this.cityId = 'konya',
    this.holdings = const [],
    this.premiumUnlocked = const [],
    this.coreIntegrity = 1,
    this.raidCount = 0,
    this.score = 0,
    this.storyDayShown = 0,
    this.savedAtMs = 0,
  });

  final List<SavedStructure> structures;
  final int money;
  final double coins;
  final double energy;
  final int dayNumber;
  final double timeOfDay;
  final int workloadIndex;

  /// Which zone the site stands in.
  final int zoneIndex;

  /// Which province the site stands in.
  final String cityId;

  /// Every plot held, and which premium locations have been unlocked.
  final List<LandHolding> holdings;
  final List<String> premiumUnlocked;

  /// Core health as a fraction, so a battered core stays battered.
  final double coreIntegrity;

  final int raidCount;
  final int score;

  /// Highest day whose story beat has already been read.
  final int storyDayShown;

  /// Wall-clock time of the save, in milliseconds since epoch. Offline income
  /// is computed against this.
  final int savedAtMs;

  bool get isEmpty => structures.isEmpty && money == 0 && dayNumber == 1;

  String encode() => jsonEncode({
        's': structures.map((e) => e.toJson()).toList(),
        'm': money,
        'c': coins,
        'e': energy,
        'd': dayNumber,
        'tod': timeOfDay,
        'w': workloadIndex,
        'z': zoneIndex,
        'city': cityId,
        'hold': holdings.map((e) => e.toJson()).toList(),
        'prem': premiumUnlocked,
        'ci': coreIntegrity,
        'rc': raidCount,
        'sc': score,
        'sd': storyDayShown,
        'at': savedAtMs,
      });

  static BaseSave decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final list = (j['s'] as List<dynamic>? ?? const [])
        .map((e) => SavedStructure.fromJson(e as Map<String, dynamic>))
        .whereType<SavedStructure>()
        .toList();
    return BaseSave(
      structures: list,
      money: (j['m'] as num?)?.toInt() ?? 0,
      coins: (j['c'] as num?)?.toDouble() ?? 0,
      energy: (j['e'] as num?)?.toDouble() ?? 0,
      dayNumber: (j['d'] as num?)?.toInt() ?? 1,
      timeOfDay: (j['tod'] as num?)?.toDouble() ?? 0.28,
      workloadIndex: (j['w'] as num?)?.toInt() ?? 0,
      zoneIndex: (j['z'] as num?)?.toInt() ?? 0,
      cityId: j['city'] as String? ?? 'konya',
      holdings: ((j['hold'] as List<dynamic>?) ?? const [])
          .map((e) => LandHolding.fromJson(e as Map<String, dynamic>))
          .toList(),
      premiumUnlocked: ((j['prem'] as List<dynamic>?) ?? const [])
          .map((e) => e as String)
          .toList(),
      coreIntegrity: (j['ci'] as num?)?.toDouble() ?? 1,
      raidCount: (j['rc'] as num?)?.toInt() ?? 0,
      score: (j['sc'] as num?)?.toInt() ?? 0,
      storyDayShown: (j['sd'] as num?)?.toInt() ?? 0,
      savedAtMs: (j['at'] as num?)?.toInt() ?? 0,
    );
  }
}

/// What the site produced while the app was closed.
@immutable
class OfflineReport {
  const OfflineReport({
    required this.seconds,
    required this.money,
    required this.coins,
    this.wasted = 0,
    this.vaultCapacity = 0,
    this.hoursToFill = 0,
  });

  final double seconds;
  final int money;
  final double coins;

  /// Production the site made but could not hold. Seeing this is the point:
  /// it is what turns "I'll check in later" into "I'll check in tonight".
  final int wasted;
  final int vaultCapacity;

  /// How long the site can run unattended before it starts spilling.
  final double hoursToFill;

  bool get isWorthShowing => seconds > 60 && (money > 0 || coins > 0);
}
