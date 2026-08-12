import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;

import '../../models/level_config.dart';
import '../../models/tower_type.dart';
import 'iso_component.dart';

/// Shared base for every player-built structure on the board.
///
/// Gives each one hit points, a damage/repair lifecycle and the visual language
/// for it: raiders can attack anything, damaged buildings degrade and stop
/// working, money repairs them, and a structure that falls is destroyed and must
/// be rebuilt from scratch.
abstract class StructureComponent extends IsoComponent {
  StructureComponent({
    required this.spec,
    required this.coord,
    required super.depthBias,
    this.tier = 0,
  }) : super(tile: Vector2(coord.col.toDouble(), coord.row.toDouble()));

  final TowerSpec spec;
  final TileCoord coord;
  int tier;

  double _health = 0;
  double _maxHealth = 0;
  double _hitFlash = 0;
  bool _destroyed = false;

  TowerTier get currentTier => spec.tier(tier);
  bool get canUpgrade => tier < spec.maxTier;
  int? get upgradeCost => canUpgrade ? spec.tier(tier + 1).cost : null;

  double get health => _health;
  double get maxHealth => _maxHealth;
  double get healthFraction =>
      _maxHealth <= 0 ? 1 : (_health / _maxHealth).clamp(0.0, 1.0);
  bool get isDestroyed => _destroyed;

  /// Below this, the structure is knocked offline: it stops producing/firing
  /// until repaired, which is what makes ignoring damage actually hurt.
  static const double offlineThreshold = 0.3;
  bool get isOffline => healthFraction < offlineThreshold;

  /// Health scales with tier — upgraded equipment is sturdier.
  double get baseMaxHealth => 60.0 + 40.0 * tier;

  /// Money to fully repair from the current damage. Cheaper than rebuilding,
  /// which is the point: maintain, or pay full price again.
  int get repairCost {
    final missing = 1.0 - healthFraction;
    if (missing <= 0.001) return 0;
    return (spec.tier(tier).cost * 0.6 * missing).ceil();
  }

  bool get needsRepair => healthFraction < 0.999;

  @override
  void onMount() {
    super.onMount();
    if (_maxHealth == 0) {
      _maxHealth = baseMaxHealth;
      _health = _maxHealth;
    }
  }

  void upgrade() {
    if (!canUpgrade) return;
    tier++;
    // Upgrading restores the unit and raises its ceiling.
    final ratio = healthFraction;
    _maxHealth = baseMaxHealth;
    _health = _maxHealth * ratio.clamp(0.5, 1.0);
  }

  void repairFully() {
    _health = _maxHealth;
  }

  /// Raider damage. Returns true if this destroyed the structure.
  bool takeStructureDamage(double amount) {
    if (_destroyed) return false;
    _health -= amount;
    _hitFlash = 0.2;
    if (_health <= 0) {
      _health = 0;
      _destroyed = true;
      return true;
    }
    return false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_hitFlash > 0) _hitFlash = (_hitFlash - dt).clamp(0, 1);
  }

  /// Draw damage state on top of the structure's own art. Subclasses call this
  /// at the end of their render.
  void renderDamageOverlay(Canvas canvas) {
    final halfW = game.iso.halfW;
    final halfH = game.iso.halfH;

    if (_hitFlash > 0) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(0, -halfH * 0.6),
            width: halfW * 1.4,
            height: halfH * 1.4),
        Paint()..color = Colors.red.withValues(alpha: 0.30 * _hitFlash),
      );
    }

    if (!needsRepair) return;

    // Health bar above the structure.
    const w = 26.0, h = 4.0;
    final y = -halfH * 2.8;
    canvas.drawRect(
      Rect.fromLTWH(-w / 2, y, w, h),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    final frac = healthFraction;
    canvas.drawRect(
      Rect.fromLTWH(-w / 2, y, w * frac, h),
      Paint()
        ..color = frac > 0.6
            ? const Color(0xFF4CD07D)
            : frac > offlineThreshold
                ? const Color(0xFFF5B301)
                : const Color(0xFFE23D4B),
    );

    // Offline units get a clear warning badge.
    if (isOffline) {
      canvas.drawCircle(Offset(0, y - 9), 6,
          Paint()..color = const Color(0xFFE23D4B));
      final x = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.8;
      canvas.drawLine(Offset(-2.5, y - 11.5), Offset(2.5, y - 6.5), x);
      canvas.drawLine(Offset(-2.5, y - 6.5), Offset(2.5, y - 11.5), x);
    }
  }
}
