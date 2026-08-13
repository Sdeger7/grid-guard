import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'tower_type.dart';

/// Permanent, cross-session player progression. Serialized by [SaveService].
///
/// Everything here survives between runs: unlocks, currencies, per-level star
/// records and the interstitial pacing counter. Per-run state lives in
/// [LevelState] instead.
@immutable
class PlayerProfile {
  const PlayerProfile({
    this.gridCredits = 0,
    this.energyCores = 0,
    this.highestZoneReached = 1,
    this.highestLevelReached = 1,
    this.starsByLevelId = const {},
    this.unlockedTowers = const {
      TowerType.pvPanel,
      TowerType.windTurbine,
      TowerType.scissorBarrier,
      TowerType.shockTransformer,
    },
    this.ownedSkins = const {},
    this.purchasedSkus = const {},
    this.levelsCompletedSinceInterstitial = 0,
    this.totalLevelsCompleted = 0,
    this.coins = 0,
    this.bestRaid = 0,
    this.bestScore = 0,
    this.ownedPackages = const {},
    this.equippedSkins = const {},
    this.streakDays = 0,
    this.lastPlayedEpochDay = 0,
    this.streakClaimedEpochDay = 0,
    this.challengeScores = const {},
    this.challengeSettled = const {},
  });

  /// WATT mined by crypto workloads — the permanent currency for perks and
  /// cosmetics. Fractional, because mining produces hundredths per hour: held
  /// as a whole number it rounded every session's earnings to nothing.
  final double coins;

  /// Best endless run so far.
  final int bestRaid;
  final int bestScore;

  /// Premium packages bought with WATT.
  final Set<String> ownedPackages;

  /// Consecutive days the player has opened the game, the last day they did,
  /// and the last day they took the streak reward. Days are counted as whole
  /// local days since the epoch.
  final int streakDays;
  final int lastPlayedEpochDay;
  final int streakClaimedEpochDay;

  /// Best score per weekly challenge, keyed by week number.
  final Map<int, int> challengeScores;

  /// Which challenge weeks have already paid their reward — a week pays once.
  final Map<int, bool> challengeSettled;

  /// Which cosmetic set is worn in each slot, keyed by SkinSlot.name. What is
  /// owned lives in [ownedSkins].
  final Map<String, String> equippedSkins;

  /// Permanent soft currency.
  final int gridCredits;

  /// Hard currency. Field exists from day one; nothing grants it yet.
  final int energyCores;

  /// Furthest zone/level unlocked (1-based).
  final int highestZoneReached;
  final int highestLevelReached;

  /// Best star count achieved per level id.
  final Map<int, int> starsByLevelId;

  final Set<TowerType> unlockedTowers;

  /// Cosmetic skin ids owned (store).
  final Set<String> ownedSkins;

  /// IAP SKUs marked purchased (mock).
  final Set<String> purchasedSkus;

  /// Interstitials fire every few levels; this counts completions since the
  /// last interstitial so [ui] can pace them.
  final int levelsCompletedSinceInterstitial;

  final int totalLevelsCompleted;

  int starsFor(int levelId) => starsByLevelId[levelId] ?? 0;

  bool isLevelUnlocked(int zone, int indexInZone) {
    if (zone < highestZoneReached) return true;
    if (zone > highestZoneReached) return false;
    return indexInZone <= highestLevelReached;
  }

  PlayerProfile copyWith({
    int? gridCredits,
    int? energyCores,
    int? highestZoneReached,
    int? highestLevelReached,
    Map<int, int>? starsByLevelId,
    Set<TowerType>? unlockedTowers,
    Set<String>? ownedSkins,
    Set<String>? purchasedSkus,
    int? levelsCompletedSinceInterstitial,
    int? totalLevelsCompleted,
    double? coins,
    int? bestRaid,
    int? bestScore,
    Set<String>? ownedPackages,
    Map<String, String>? equippedSkins,
    int? streakDays,
    int? lastPlayedEpochDay,
    int? streakClaimedEpochDay,
    Map<int, int>? challengeScores,
    Map<int, bool>? challengeSettled,
  }) {
    return PlayerProfile(
      gridCredits: gridCredits ?? this.gridCredits,
      energyCores: energyCores ?? this.energyCores,
      highestZoneReached: highestZoneReached ?? this.highestZoneReached,
      highestLevelReached: highestLevelReached ?? this.highestLevelReached,
      starsByLevelId: starsByLevelId ?? this.starsByLevelId,
      unlockedTowers: unlockedTowers ?? this.unlockedTowers,
      ownedSkins: ownedSkins ?? this.ownedSkins,
      purchasedSkus: purchasedSkus ?? this.purchasedSkus,
      levelsCompletedSinceInterstitial: levelsCompletedSinceInterstitial ??
          this.levelsCompletedSinceInterstitial,
      totalLevelsCompleted:
          totalLevelsCompleted ?? this.totalLevelsCompleted,
      coins: coins ?? this.coins,
      bestRaid: bestRaid ?? this.bestRaid,
      bestScore: bestScore ?? this.bestScore,
      ownedPackages: ownedPackages ?? this.ownedPackages,
      equippedSkins: equippedSkins ?? this.equippedSkins,
      streakDays: streakDays ?? this.streakDays,
      lastPlayedEpochDay: lastPlayedEpochDay ?? this.lastPlayedEpochDay,
      streakClaimedEpochDay:
          streakClaimedEpochDay ?? this.streakClaimedEpochDay,
      challengeScores: challengeScores ?? this.challengeScores,
      challengeSettled: challengeSettled ?? this.challengeSettled,
    );
  }

  Map<String, dynamic> toJson() => {
        'gridCredits': gridCredits,
        'energyCores': energyCores,
        'highestZoneReached': highestZoneReached,
        'highestLevelReached': highestLevelReached,
        // JSON object keys must be strings.
        'starsByLevelId':
            starsByLevelId.map((k, v) => MapEntry(k.toString(), v)),
        'unlockedTowers': unlockedTowers.map((t) => t.name).toList(),
        'ownedSkins': ownedSkins.toList(),
        'purchasedSkus': purchasedSkus.toList(),
        'levelsCompletedSinceInterstitial': levelsCompletedSinceInterstitial,
        'totalLevelsCompleted': totalLevelsCompleted,
        'coins': coins,
        'bestRaid': bestRaid,
        'bestScore': bestScore,
        'ownedPackages': ownedPackages.toList(),
        'equippedSkins': equippedSkins,
        'streakDays': streakDays,
        'lastPlayedEpochDay': lastPlayedEpochDay,
        'streakClaimedEpochDay': streakClaimedEpochDay,
        'challengeScores':
            challengeScores.map((k, v) => MapEntry(k.toString(), v)),
        'challengeSettled':
            challengeSettled.map((k, v) => MapEntry(k.toString(), v)),
      };

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      gridCredits: json['gridCredits'] as int? ?? 0,
      energyCores: json['energyCores'] as int? ?? 0,
      highestZoneReached: json['highestZoneReached'] as int? ?? 1,
      highestLevelReached: json['highestLevelReached'] as int? ?? 1,
      starsByLevelId: (json['starsByLevelId'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(int.parse(k), v as int)),
      unlockedTowers: (json['unlockedTowers'] as List?)
              ?.map((t) => TowerType.values.byName(t as String))
              .toSet() ??
          const {
            TowerType.pvPanel,
            TowerType.windTurbine,
            TowerType.scissorBarrier,
            TowerType.shockTransformer,
          },
      streakDays: json['streakDays'] as int? ?? 0,
      lastPlayedEpochDay: json['lastPlayedEpochDay'] as int? ?? 0,
      streakClaimedEpochDay: json['streakClaimedEpochDay'] as int? ?? 0,
      challengeScores:
          ((json['challengeScores'] as Map<String, dynamic>?) ?? const {})
              .map((k, v) => MapEntry(int.parse(k), v as int)),
      challengeSettled:
          ((json['challengeSettled'] as Map<String, dynamic>?) ?? const {})
              .map((k, v) => MapEntry(int.parse(k), v as bool)),
      equippedSkins: ((json['equippedSkins'] as Map<String, dynamic>?) ??
              const <String, dynamic>{})
          .map((k, v) => MapEntry(k, v as String)),
      ownedSkins:
          (json['ownedSkins'] as List?)?.map((s) => s as String).toSet() ??
              const {},
      purchasedSkus:
          (json['purchasedSkus'] as List?)?.map((s) => s as String).toSet() ??
              const {},
      levelsCompletedSinceInterstitial:
          json['levelsCompletedSinceInterstitial'] as int? ?? 0,
      totalLevelsCompleted: json['totalLevelsCompleted'] as int? ?? 0,
      coins: (json['coins'] as num?)?.toDouble() ?? 0,
      bestRaid: json['bestRaid'] as int? ?? 0,
      bestScore: json['bestScore'] as int? ?? 0,
      ownedPackages:
          (json['ownedPackages'] as List?)?.map((e) => e as String).toSet() ??
              const {},
    );
  }

  String encode() => jsonEncode(toJson());

  factory PlayerProfile.decode(String source) =>
      PlayerProfile.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
