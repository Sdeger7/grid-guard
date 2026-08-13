import 'package:flutter/foundation.dart';

/// Well-known placement ids so callers don't pass raw strings around.
class AdPlacements {
  static const continueRun = 'continue';
  static const doubleReward = 'double_reward';
  static const dailyBonus = 'daily_bonus';

  /// Doubles a welcome-back payout. Optional, capped, and never the only way
  /// to get anything — an ad the player chooses is worth more than one they
  /// resent.
  static const doubleOffline = 'double_offline';
}

/// Well-known IAP SKUs.
class Skus {
  static const starterPack = 'starter_pack';
}

/// The single seam between the game and any ad/IAP SDK.
///
/// Everything in the game — rewarded ads, interstitials, purchase checks — goes
/// through this interface. The real SDK (`google_mobile_ads`, `in_app_purchase`)
/// is deliberately NOT a dependency yet: ship [MockMonetizationService], and
/// later swap in a real implementation without touching any gameplay code.
abstract class MonetizationService {
  /// Shows a rewarded ad for [placementId]. Resolves to `true` if the reward
  /// was earned (ad watched to completion), `false` if dismissed/failed.
  Future<bool> showRewardedAd(String placementId);

  /// Shows an interstitial. Fire-and-forget; never blocks a reward.
  Future<void> showInterstitial();

  /// Whether a non-consumable IAP [sku] has been purchased.
  bool isProductPurchased(String sku);

  /// Kicks off a (mock) purchase flow, resolving true on success.
  Future<bool> purchase(String sku);
}

/// A no-SDK stand-in that makes the whole game playable and testable offline.
/// Rewarded ads "succeed" after a short fake delay; purchases are remembered in
/// memory only.
class MockMonetizationService implements MonetizationService {
  MockMonetizationService({this.simulatedDelay = const Duration(seconds: 1)});

  final Duration simulatedDelay;
  final Set<String> _purchased = {};

  @override
  Future<bool> showRewardedAd(String placementId) async {
    debugPrint('[MockAds] rewarded ad requested: $placementId');
    await Future<void>.delayed(simulatedDelay);
    debugPrint('[MockAds] rewarded ad completed: $placementId -> reward');
    return true;
  }

  @override
  Future<void> showInterstitial() async {
    debugPrint('[MockAds] interstitial shown');
    await Future<void>.delayed(simulatedDelay);
  }

  @override
  bool isProductPurchased(String sku) => _purchased.contains(sku);

  @override
  Future<bool> purchase(String sku) async {
    debugPrint('[MockAds] purchase requested: $sku');
    await Future<void>.delayed(simulatedDelay);
    _purchased.add(sku);
    return true;
  }
}
