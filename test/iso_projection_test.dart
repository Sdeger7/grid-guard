import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_guard/game/systems/iso.dart';

void main() {
  group('IsoProjection', () {
    final iso = IsoProjection(tileWidth: 64);

    test('tile height is half the width (2:1)', () {
      expect(iso.tileHeight, 32);
    });

    test('screenToTile inverts tileToScreen', () {
      for (final coord in [
        [0.0, 0.0],
        [3.0, 5.0],
        [8.0, 2.0],
        [4.5, 6.25],
      ]) {
        final screen = iso.tileToScreen(coord[0], coord[1]);
        final back = iso.screenToTile(screen.x, screen.y);
        expect(back.x, closeTo(coord[0], 1e-9));
        expect(back.y, closeTo(coord[1], 1e-9));
      }
    });

    test('tap picking floors to the right tile', () {
      final center = iso.tileToScreen(3, 4);
      final coord = iso.screenToTileCoord(center.x, center.y, 9, 9);
      expect(coord, isNotNull);
      expect(coord!.col, 3);
      expect(coord.row, 4);
    });

    test('out-of-grid taps return null', () {
      final screen = iso.tileToScreen(-2, -2);
      expect(iso.screenToTileCoord(screen.x, screen.y, 9, 9), isNull);
    });

    test('depth increases toward the camera', () {
      expect(IsoProjection.depth(1, 1) < IsoProjection.depth(5, 5), isTrue);
    });

    test('worldBounds spans the full grid', () {
      final b = iso.worldBounds(9, 9);
      expect(b.width, greaterThan(0));
      expect(b.height, greaterThan(0));
      // A point recentred by origin must be non-negative.
      final p = iso.tileToScreen(0, 8) + b.origin;
      expect(p.x, greaterThanOrEqualTo(-1e-6));
      expect(p.y, greaterThanOrEqualTo(-1e-6));
    });
  });
}
