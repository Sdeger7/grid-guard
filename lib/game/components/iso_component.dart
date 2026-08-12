import 'dart:ui';

import 'package:flame/components.dart';

import '../grid_guard_game.dart';

/// Base for anything that lives on the isometric board.
///
/// It owns a fractional tile position (`col,row`) and keeps its screen
/// [position] and render [priority] in sync with the projection every frame.
/// Depth sorting is therefore centralised here — no component sorts itself
/// ad-hoc; they all inherit the same `(col+row)` ordering via [syncIso].
abstract class IsoComponent extends PositionComponent
    with HasGameReference<GridGuardGame> {
  IsoComponent({
    required this.tile,
    super.size,
    super.anchor = Anchor.center,
    this.depthBias = 0,
  });

  /// Fractional tile coordinate (col, row). Mutate this, not [position].
  Vector2 tile;

  /// Nudges draw order for objects sharing a tile (e.g. a tower above ground).
  final double depthBias;

  int _lastPriority = 1 << 30;

  double get depth => tile.x + tile.y + depthBias;

  /// Converts tile -> screen and updates priority. Called every frame; priority
  /// is only reassigned when it actually changes so the parent doesn't re-sort
  /// needlessly.
  void syncIso() {
    position = game.iso.tileToScreen(tile.x, tile.y);
    final p = (depth * 1000).toInt();
    if (p != _lastPriority) {
      priority = p;
      _lastPriority = p;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    syncIso();
  }

  /// Draws a unit [sprite] seated on the tile: scaled to [widthTiles] tile
  /// widths, with the frame's bottom sunk [sinkFrac] of its height below the
  /// tile centre (these art frames carry empty space under the base pad, so a
  /// small sink lands the visible base on the tile). Used when real art exists.
  void drawUnitSprite(
    Canvas canvas,
    Sprite sprite, {
    double widthTiles = 1.5,
    double sinkFrac = 0.16,
  }) {
    final w = game.iso.tileWidth * widthTiles;
    final h = w * sprite.srcSize.y / sprite.srcSize.x;
    sprite.render(
      canvas,
      position: Vector2(0, h * sinkFrac),
      size: Vector2(w, h),
      anchor: Anchor.bottomCenter,
    );
  }
}
