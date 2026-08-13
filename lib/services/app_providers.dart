import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/level_state.dart';
import '../data/watt_supply.dart';
import '../data/streak.dart';
import '../models/player_profile.dart';
import 'leaderboard_service.dart';
import 'weather_service.dart';
import '../models/star_rating.dart';
import '../models/tower_type.dart';
import 'audio_service.dart';
import 'monetization_service.dart';
import 'save_service.dart';

/// Provides the [SaveService]. Overridden in `main()` with the real instance
/// once shared_preferences has initialised.
/// Live weather for the site's province. Optional by design: without it the
/// game falls back to its own weather model and plays exactly as before.
final weatherServiceProvider = Provider<WeatherService?>((ref) => null);

/// Where challenge results are recorded. Overridden at startup with the local
/// implementation; swapping in a networked one is a one-line change here.
final leaderboardProvider = Provider<LeaderboardService>(
  (ref) => throw UnimplementedError('leaderboardProvider must be overridden'),
);

final saveServiceProvider = Provider<SaveService>(
  (ref) => throw UnimplementedError('saveServiceProvider must be overridden'),
);

/// The monetization seam. Swap [MockMonetizationService] for a real SDK-backed
/// implementation here — nothing else in the app changes.
final monetizationServiceProvider = Provider<MonetizationService>(
  (ref) => MockMonetizationService(),
);

/// Centralised SFX. Preloaded at startup (see `main()`).
final audioServiceProvider = Provider<AudioService>((ref) => AudioService());

/// The player's persistent profile, loaded from disk on first read and written
/// back through [SaveService] on every mutation.
class ProfileNotifier extends Notifier<PlayerProfile> {
  @override
  PlayerProfile build() => ref.read(saveServiceProvider).loadProfile();

  SaveService get _save => ref.read(saveServiceProvider);

  Future<void> applyLevelResult(LevelResult result,
      {required int zone, required int indexInZone}) async {
    state = await _save.applyLevelResult(
      state,
      levelId: result.levelId,
      zone: zone,
      indexInZone: indexInZone,
      stars: result.stars,
      gridCreditsEarned: result.baseGridCredits,
    );
  }

  /// Awards the extra Grid Credits from a "2x reward" rewarded ad.
  Future<void> awardBonusCredits(int amount) async {
    state = state.copyWith(gridCredits: state.gridCredits + amount);
    await _save.saveProfile(state);
  }

  Future<bool> spendGridCredits(int amount) async {
    if (state.gridCredits < amount) return false;
    state = state.copyWith(gridCredits: state.gridCredits - amount);
    await _save.saveProfile(state);
    return true;
  }

  Future<void> unlockTower(TowerType type) async {
    state = state.copyWith(unlockedTowers: {...state.unlockedTowers, type});
    await _save.saveProfile(state);
  }

  Future<void> grantSkin(String skinId) async {
    state = state.copyWith(ownedSkins: {...state.ownedSkins, skinId});
    await _save.saveProfile(state);
  }

  /// Banks WATT mined in a run and updates endless records.
  Future<void> bankRunResults({
    required double coins,
    required int raid,
    required int score,
  }) async {
    state = state.copyWith(
      coins: state.coins + coins,
      bestRaid: raid > state.bestRaid ? raid : state.bestRaid,
      bestScore: score > state.bestScore ? score : state.bestScore,
    );
    await _save.saveProfile(state);
  }

  /// Advances the login streak for today, if it has not run yet.
  ///
  /// Returns the streak day the player is now on, or null when today has
  /// already been counted. Missing a day resets the streak to one — that reset
  /// is the whole reason the mechanic works.
  Future<int?> touchStreak() async {
    final today = StreakCalendar.today();
    final p = state;
    if (p.lastPlayedEpochDay == today) return null;

    final consecutive = p.lastPlayedEpochDay == today - 1;
    final next = consecutive ? p.streakDays + 1 : 1;
    final wrapped = next > StreakCalendar.cycle ? 1 : next;

    final updated = p.copyWith(
      streakDays: wrapped,
      lastPlayedEpochDay: today,
    );
    state = updated;
    await ref.read(saveServiceProvider).saveProfile(updated);
    return wrapped;
  }

  /// Pays today's streak reward once.
  Future<void> claimStreak() async {
    final today = StreakCalendar.today();
    final p = state;
    if (p.streakClaimedEpochDay == today) return;
    final reward = StreakCalendar.rewardFor(p.streakDays);
    // Streak WATT comes out of the treasury, so a milestone never mints any.
    final fromTreasury = math.min(reward.watt, p.treasury);
    final updated = p.copyWith(
      streakClaimedEpochDay: today,
      treasury: p.treasury - fromTreasury,
      coins: p.coins + fromTreasury,
      ownedSkins: reward.skinId == null
          ? p.ownedSkins
          : {...p.ownedSkins, reward.skinId!},
    );
    state = updated;
    await ref.read(saveServiceProvider).saveProfile(updated);
  }

  /// Pays the entry fee for a week. Returns false if already entered or the
  /// balance is short.
  Future<bool> enterChallenge(int week, double fee) async {
    final p = state;
    if (p.challengeEntered[week] == true || p.coins < fee) return false;
    final updated = p.copyWith(
      coins: p.coins - fee,
      challengeEntered: {...p.challengeEntered, week: true},
    );
    state = updated;
    await ref.read(saveServiceProvider).saveProfile(updated);
    return true;
  }

  /// Banks the share of a prize pool that was not paid to the places.
  Future<void> depositRake(double pool) async {
    final updated = state.copyWith(
      treasury: state.treasury + WattTreasury.rakeFrom(pool),
    );
    state = updated;
    await ref.read(saveServiceProvider).saveProfile(updated);
  }

  /// Pays a reward out of the treasury, never out of thin air. Returns what
  /// was actually paid, which is nothing when the treasury is empty.
  Future<double> payFromTreasury(double amount) async {
    final p = state;
    final paid = math.min(amount, p.treasury);
    if (paid <= 0) return 0;
    final updated = p.copyWith(
      treasury: p.treasury - paid,
      coins: p.coins + paid,
    );
    state = updated;
    await ref.read(saveServiceProvider).saveProfile(updated);
    return paid;
  }

  /// Pays a week's prize, once.
  Future<double> awardChallengeReward(int week, double watt) async {
    final p = state;
    if (p.challengeSettled[week] == true || watt <= 0) return 0;
    final updated = p.copyWith(
      coins: p.coins + watt,
      challengeSettled: {...p.challengeSettled, week: true},
    );
    state = updated;
    await ref.read(saveServiceProvider).saveProfile(updated);
    return watt;
  }

  /// Records a challenge result, keeping the best score for that week.
  Future<void> recordChallengeScore(int week, int score) async {
    final p = state;
    final best = p.challengeScores[week] ?? 0;
    if (score <= best) return;
    final updated = p.copyWith(
      challengeScores: {...p.challengeScores, week: score},
    );
    state = updated;
    await ref.read(saveServiceProvider).saveProfile(updated);
  }

  /// Buys a cosmetic set with WATT. Returns false when the balance is short.
  Future<bool> buySkin(String id, int price) async {
    final p = state;
    if (p.ownedSkins.contains(id)) return true;
    if (p.coins < price) return false;
    final next = p.copyWith(
      coins: p.coins - price,
      ownedSkins: {...p.ownedSkins, id},
    );
    state = next;
    await ref.read(saveServiceProvider).saveProfile(next);
    return true;
  }

  /// Wears a cosmetic set in its slot.
  Future<void> equipSkin(String slot, String id) async {
    final next = state.copyWith(
      equippedSkins: {...state.equippedSkins, slot: id},
    );
    state = next;
    await ref.read(saveServiceProvider).saveProfile(next);
  }

  /// Buys a premium package with WATT. Returns false when short.
  Future<bool> buyPackage(String id, int price) async {
    if (state.coins < price || state.ownedPackages.contains(id)) return false;
    state = state.copyWith(
      coins: state.coins - price,
      ownedPackages: {...state.ownedPackages, id},
    );
    await _save.saveProfile(state);
    return true;
  }

  Future<void> markPurchased(String sku) async {
    state = state.copyWith(purchasedSkus: {...state.purchasedSkus, sku});
    await _save.saveProfile(state);
  }

  /// Interstitials fire every 2–3 completed levels. Returns true and resets the
  /// counter when one is due (never on the very first completion overall).
  bool consumeInterstitialSlotIfDue() {
    final due = state.totalLevelsCompleted > 1 &&
        state.levelsCompletedSinceInterstitial >= 3;
    if (due) {
      state = state.copyWith(levelsCompletedSinceInterstitial: 0);
      _save.saveProfile(state);
    }
    return due;
  }

  Future<void> resetProgress() async {
    await _save.resetAll();
    state = const PlayerProfile();
  }
}

final profileProvider =
    NotifierProvider<ProfileNotifier, PlayerProfile>(ProfileNotifier.new);

/// The live HUD snapshot the running game publishes each throttled tick. Null
/// when no level is active.
final levelStateProvider = StateProvider<LevelState?>((ref) => null);

/// Convenience: best-known [StarRating] for a level id.
StarRating starsForLevel(WidgetRef ref, int levelId) =>
    StarRating.fromCount(ref.watch(profileProvider).starsFor(levelId));
