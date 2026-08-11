import 'package:flutter_test/flutter_test.dart';
import 'package:grid_guard/models/player_profile.dart';
import 'package:grid_guard/models/tower_type.dart';

void main() {
  group('PlayerProfile serialization', () {
    test('round-trips through encode/decode', () {
      const profile = PlayerProfile(
        gridCredits: 340,
        energyCores: 12,
        highestZoneReached: 2,
        highestLevelReached: 4,
        starsByLevelId: {1: 3, 2: 2, 7: 1},
        ownedSkins: {'skin_pv_solaris'},
        purchasedSkus: {'starter_pack'},
        levelsCompletedSinceInterstitial: 2,
        totalLevelsCompleted: 9,
      );

      final decoded = PlayerProfile.decode(profile.encode());

      expect(decoded.gridCredits, 340);
      expect(decoded.energyCores, 12);
      expect(decoded.highestZoneReached, 2);
      expect(decoded.highestLevelReached, 4);
      expect(decoded.starsFor(1), 3);
      expect(decoded.starsFor(2), 2);
      expect(decoded.starsFor(7), 1);
      expect(decoded.starsFor(99), 0);
      expect(decoded.ownedSkins, contains('skin_pv_solaris'));
      expect(decoded.purchasedSkus, contains('starter_pack'));
      expect(decoded.unlockedTowers, contains(TowerType.shockTransformer));
      expect(decoded.totalLevelsCompleted, 9);
    });

    test('a default profile has starter towers and locks later zones', () {
      const p = PlayerProfile();
      expect(p.unlockedTowers, contains(TowerType.pvPanel));
      expect(p.isLevelUnlocked(1, 1), isTrue);
      expect(p.isLevelUnlocked(1, 2), isFalse);
      expect(p.isLevelUnlocked(2, 1), isFalse);
    });
  });
}
