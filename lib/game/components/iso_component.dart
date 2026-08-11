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
}
