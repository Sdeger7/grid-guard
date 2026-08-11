import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_profile.dart';
import '../models/star_rating.dart';

/// Local, fully-offline persistence for [PlayerProfile]. Backed by
/// shared_preferences; a single JSON blob keeps reads/writes atomic and easy to
/// version later.
class SaveService {
  SaveService(this._prefs);

  static const _profileKey = 'grid_guard.player_profile.v1';

  final SharedPreferences _prefs;

  /// Convenience async constructor for app startup.
  static Future<SaveService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SaveService(prefs);
  }

  PlayerProfile loadProfile() {
    final raw = _prefs.getString(_profileKey);
    if (raw == null) return const PlayerProfile();
    try {
      return PlayerProfile.decode(raw);
    } catch (_) {
      // Corrupt/old save — start fresh rather than crash on launch.
      return const PlayerProfile();
    }
  }

  Future<void> saveProfile(PlayerProfile profile) async {
    await _prefs.setString(_profileKey, profile.encode());
  }

  /// Records a level result into the profile: best-stars merge, unlock advance,
  /// and currency award. Returns the updated profile (also persisted).
  Future<PlayerProfile> applyLevelResult(
    PlayerProfile profile, {
    required int levelId,
    required int zone,
    required int indexInZone,
    required StarRating stars,
    required int gridCreditsEarned,
  }) async {
    if (!stars.isWin) {
      await saveProfile(profile);
      return profile;
    }

    final prevStars = StarRating.fromCount(profile.starsFor(levelId));
    final bestStars = stars.mergeBest(prevStars);

    final newStarsMap = Map<int, int>.from(profile.starsByLevelId)
      ..[levelId] = bestStars.count;

    // Advance the unlock frontier to the next level.
    var nextZone = profile.highestZoneReached;
    var nextLevel = profile.highestLevelReached;
    if (zone == nextZone && indexInZone == nextLevel) {
      if (indexInZone < 6) {
        nextLevel = indexInZone + 1;
      } else if (zone < 5) {
        nextZone = zone + 1;
        nextLevel = 1;
      }
    }

    final updated = profile.copyWith(
      starsByLevelId: newStarsMap,
      highestZoneReached: nextZone,
      highestLevelReached: nextLevel,
      gridCredits: profile.gridCredits + gridCreditsEarned,
      levelsCompletedSinceInterstitial:
          profile.levelsCompletedSinceInterstitial + 1,
      totalLevelsCompleted: profile.totalLevelsCompleted + 1,
    );
    await saveProfile(updated);
    return updated;
  }

  Future<void> resetAll() async => _prefs.remove(_profileKey);
}
