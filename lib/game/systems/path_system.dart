import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../models/level_config.dart';

/// The enemy path, defined and interpolated entirely in **tile space** so
/// movement stays correct regardless of the isometric projection. Screen
/// conversion happens only at render time via [IsoProjection].
class PathSystem {
  PathSystem(this.waypoints)
      : assert(waypoints.length >= 2, 'A path needs at least two waypoints') {
    _buildSegments();
  }

  final List<TileCoord> waypoints;

  /// Cumulative tile-space length up to the start of each segment.
  final List<double> _cumulative = [];
  double _totalLength = 0;

  double get totalLength => _totalLength;

  void _buildSegments() {
    _cumulative.clear();
    double acc = 0;
    for (var i = 0; i < waypoints.length - 1; i++) {
      _cumulative.add(acc);
      acc += _segmentLength(i);
    }
    _cumulative.add(acc);
    _totalLength = acc;
  }

  double _segmentLength(int i) {
    final a = waypoints[i];
    final b = waypoints[i + 1];
    final dc = (b.col - a.col).toDouble();
    final dr = (b.row - a.row).toDouble();
    return math.sqrt(dc * dc + dr * dr);
  }

  /// Fractional (col,row) at a given distance travelled along the path. Clamps
  /// to the endpoints.
  Vector2 positionAtDistance(double distance) {
    if (distance <= 0) {
      return Vector2(waypoints.first.col.toDouble(),
          waypoints.first.row.toDouble());
    }
    if (distance >= _totalLength) {
      return Vector2(
          waypoints.last.col.toDouble(), waypoints.last.row.toDouble());
    }
    // Find the segment containing this distance.
    for (var i = 0; i < waypoints.length - 1; i++) {
      final segStart = _cumulative[i];
      final segEnd = _cumulative[i + 1];
      if (distance <= segEnd) {
        final t = (distance - segStart) / (segEnd - segStart);
        final a = waypoints[i];
        final b = waypoints[i + 1];
        return Vector2(
          a.col + (b.col - a.col) * t,
          a.row + (b.row - a.row) * t,
        );
      }
    }
    return Vector2(
        waypoints.last.col.toDouble(), waypoints.last.row.toDouble());
  }

  /// Nearest integer tile at a given distance — used to look up per-tile
  /// modifiers such as Scissor Barrier slows.
  TileCoord tileAtDistance(double distance) {
    final p = positionAtDistance(distance);
    return TileCoord(p.x.round(), p.y.round());
  }

  /// Whether this tile lies on the path (integer waypoints and the cells the
  /// straight segments pass through). Barriers may only be placed on these.
  bool isOnPath(TileCoord tile) => _pathTiles.contains(tile);

  late final Set<TileCoord> _pathTiles = _computePathTiles();

  Set<TileCoord> _computePathTiles() {
    final tiles = <TileCoord>{};
    for (var i = 0; i < waypoints.length - 1; i++) {
      final a = waypoints[i];
      final b = waypoints[i + 1];
      // Path segments are axis-aligned in this game's configs; walk the cells.
      final dc = (b.col - a.col).sign;
      final dr = (b.row - a.row).sign;
      var c = a.col, r = a.row;
      tiles.add(TileCoord(c, r));
      while (c != b.col || r != b.row) {
        if (c != b.col) c += dc;
        if (r != b.row) r += dr;
        tiles.add(TileCoord(c, r));
      }
    }
    return tiles;
  }

  Set<TileCoord> get pathTiles => _pathTiles;
}
