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
      TowerType.scissorBarrier,
      TowerType.shockTransformer,
    },
    this.ownedSkins = const {},
    this.purchasedSkus = const {},
    this.levelsCompletedSinceInterstitial = 0,
    this.totalLevelsCompleted = 0,
  });

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
            TowerType.scissorBarrier,
            TowerType.shockTransformer,
          },
      ownedSkins:
          (json['ownedSkins'] as List?)?.map((s) => s as String).toSet() ??
              const {},
      purchasedSkus:
          (json['purchasedSkus'] as List?)?.map((s) => s as String).toSet() ??
              const {},
      levelsCompletedSinceInterstitial:
          json['levelsCompletedSinceInterstitial'] as int? ?? 0,
      totalLevelsCompleted: json['totalLevelsCompleted'] as int? ?? 0,
    );
  }

  String encode() => jsonEncode(toJson());

  factory PlayerProfile.decode(String source) =>
      PlayerProfile.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
