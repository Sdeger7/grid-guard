import 'package:shared_preferences/shared_preferences.dart';

import '../models/base_save.dart';
import '../models/player_profile.dart';
import '../models/star_rating.dart';

/// Local, fully-offline persistence for [PlayerProfile]. Backed by
/// shared_preferences; a single JSON blob keeps reads/writes atomic and easy to
/// version later.
class SaveService {
  SaveService(this._prefs);

  static const _profileKey = 'grid_guard.player_profile.v1';
  static const _baseKey = 'grid_guard.base.v1';

  /// The weekly challenge runs in its own slot so it can never touch, or be
  /// helped by, the permanent site.
  static const _challengeKey = 'grid_guard.challenge.v1';

  String _slotKey(bool challenge) => challenge ? _challengeKey : _baseKey;

  final SharedPreferences _prefs;

  /// Shared with the weather cache, which has no reason to open its own store.
  SharedPreferences get prefs => _prefs;

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

  // ---- Persistent base ----

  /// The base as the player left it, or null on a first run.
  BaseSave? loadBase({bool challenge = false}) {
    final raw = _prefs.getString(_slotKey(challenge));
    if (raw == null) return null;
    try {
      return BaseSave.decode(raw);
    } catch (_) {
      // Corrupt or older-format save: better to start a fresh site than to
      // refuse to launch.
      return null;
    }
  }

  Future<void> saveBase(BaseSave base, {bool challenge = false}) async {
    await _prefs.setString(_slotKey(challenge), base.encode());
  }

  Future<void> clearBase({bool challenge = false}) async {
    await _prefs.remove(_slotKey(challenge));
  }

  /// Which challenge week the stored challenge run belongs to. A new week
  /// wipes the old run — that is what makes everyone's attempt comparable.
  int get challengeWeek => _prefs.getInt('grid_guard.challenge.week') ?? -1;

  Future<void> setChallengeWeek(int week) async =>
      _prefs.setInt('grid_guard.challenge.week', week);
}
