import 'package:flutter_test/flutter_test.dart';
import 'package:grid_guard/data/levels.dart';

void main() {
  group('LevelCatalog', () {
    test('builds 30 levels across 5 zones of 6', () {
      expect(LevelCatalog.levels.length, 30);
      for (var zone = 1; zone <= 5; zone++) {
        final inZone = LevelCatalog.levels.where((l) => l.zone == zone);
        expect(inZone.length, 6);
      }
    });

    test('every zone finale carries an Overload Boss Wave', () {
      for (var zone = 1; zone <= 5; zone++) {
        final finale = LevelCatalog.byZoneIndex(zone, 6);
        expect(finale.isZoneFinale, isTrue);
        expect(finale.waves.any((w) => w.isBossWave), isTrue);
      }
    });

    test('difficulty is non-decreasing in wave count within a zone', () {
      for (var zone = 1; zone <= 5; zone++) {
        var prev = 0;
        for (var idx = 1; idx <= 6; idx++) {
          final level = LevelCatalog.byZoneIndex(zone, idx);
          expect(level.waves.length, greaterThanOrEqualTo(prev));
          prev = level.waves.length;
        }
      }
    });

    test('paths start and end on distinct tiles', () {
      for (final level in LevelCatalog.levels) {
        expect(level.spawnTile == level.coreTile, isFalse);
        expect(level.path.length, greaterThanOrEqualTo(2));
      }
    });
  });
}
