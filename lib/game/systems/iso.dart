import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../models/level_config.dart';

/// Standard 2:1 isometric projection.
///
/// One place owns the tile<->screen transform for the whole game: tap picking,
/// tower placement and rendering all go through here, so the diamond math never
/// drifts between input and draw. A tile is [tileWidth] wide and half as tall
/// (`tileWidth / 2`), giving the classic 2:1 diamond.
class IsoProjection {
  IsoProjection({required this.tileWidth}) : tileHeight = tileWidth / 2;

  /// Full width of a tile diamond in logical pixels.
  final double tileWidth;

  /// Full height of a tile diamond (== tileWidth / 2 for 2:1).
  final double tileHeight;

  double get halfW => tileWidth / 2;
  double get halfH => tileHeight / 2;

  /// Tile (col,row) -> screen position of the tile's *center*, before the world
  /// camera/origin offset is applied. Fractional col/row is allowed so moving
  /// enemies interpolate smoothly in tile space.
  Vector2 tileToScreen(double col, double row) {
    final x = (col - row) * halfW;
    final y = (col + row) * halfH;
    return Vector2(x, y);
  }

  /// Inverse of [tileToScreen]: screen position -> fractional (col,row).
  Vector2 screenToTile(double x, double y) {
    final col = (x / halfW + y / halfH) / 2;
    final row = (y / halfH - x / halfW) / 2;
    return Vector2(col, row);
  }

  /// Screen position -> nearest integer tile, or null if outside the grid.
  TileCoord? screenToTileCoord(double x, double y, int cols, int rows) {
    final t = screenToTile(x, y);
    final col = t.x.floor();
    final row = t.y.floor();
    if (col < 0 || row < 0 || col >= cols || row >= rows) return null;
    return TileCoord(col, row);
  }

  /// The four diamond corners of a tile in screen space (for drawing/hit tests),
  /// centered on the tile center. Order: top, right, bottom, left.
  List<Vector2> tileDiamond(int col, int row) {
    final c = tileToScreen(col.toDouble(), row.toDouble());
    return [
      Vector2(c.x, c.y - halfH), // top
      Vector2(c.x + halfW, c.y), // right
      Vector2(c.x, c.y + halfH), // bottom
      Vector2(c.x - halfW, c.y), // left
    ];
  }

  /// Depth key used by the render sort. Larger == nearer the camera == drawn
  /// later (on top). For a moving unit pass fractional col/row.
  static double depth(double col, double row) => col + row;

  /// The pixel bounds a full [cols] x [rows] grid occupies, so the world can be
  /// centered. Returns (width, height, offset-to-recenter).
  ({double width, double height, Vector2 origin}) worldBounds(
      int cols, int rows) {
    // Corners of the grid in screen space.
    final corners = [
      tileToScreen(0, 0),
      tileToScreen(cols.toDouble(), 0),
      tileToScreen(0, rows.toDouble()),
      tileToScreen(cols.toDouble(), rows.toDouble()),
    ];
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final c in corners) {
      minX = math.min(minX, c.x);
      maxX = math.max(maxX, c.x);
      minY = math.min(minY, c.y);
      maxY = math.max(maxY, c.y);
    }
    return (
      width: maxX - minX,
      height: maxY - minY,
      origin: Vector2(-minX, -minY),
    );
  }
}
