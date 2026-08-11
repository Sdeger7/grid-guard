import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../data/enemy_catalog.dart';
import '../data/tower_catalog.dart';
import '../data/zone_theme.dart';
import '../models/enemy_type.dart';
import '../models/level_config.dart';
import '../models/level_state.dart';
import '../models/star_rating.dart';
import '../models/tower_type.dart';
import 'components/arc_effect.dart';
import 'components/core_component.dart';
import 'components/enemy_component.dart';
import 'components/floating_text.dart';
import 'components/ground_tile.dart';
import 'components/pv_panel_component.dart';
import 'components/tower_component.dart';
import 'systems/iso.dart';
import 'systems/path_system.dart';
import 'systems/wave_spawner.dart';

/// Describes the currently-selected placed structure, handed to the HUD so it
/// can offer an upgrade action.
class SelectedStructure {
  const SelectedStructure({
    required this.coord,
    required this.name,
    required this.tier,
    required this.maxTier,
    required this.upgradeCost,
  });
  final TileCoord coord;
  final String name;
  final int tier;
  final int maxTier;
  final int? upgradeCost;
}

/// Callbacks bridging the Flame game to the Flutter/Riverpod layer, so the game
/// itself stays free of any UI/state-management dependency.
class GameCallbacks {
  const GameCallbacks({
    required this.onSnapshot,
    required this.onFinished,
    this.onSfx,
    this.onSelection,
    this.onShake,
  });

  final void Function(LevelState state) onSnapshot;
  final void Function(LevelResult result) onFinished;
  final void Function(Sfx sfx)? onSfx;
  final void Function(SelectedStructure? selected)? onSelection;

  /// Optional hook (e.g. for haptics); the visual shake is handled internally.
  final void Function(double magnitude)? onShake;
}

/// Central SFX ids the game emits (mirrors [Sfx] in the audio service, kept
/// here so the game has no dependency on the service layer).
enum Sfx {
  towerPlace,
  towerFire,
  enemyDeath,
  coreDamage,
  waveStart,
  levelWin,
  levelLose,
}

/// The Grid Guard FlameGame: owns the isometric world, run economy, wave
/// pacing, win/lose logic and input. All rendering is depth-sorted through
/// component priorities set by [IsoComponent].
class GridGuardGame extends FlameGame {
  GridGuardGame({required this.config, required this.callbacks});

  final LevelConfig config;
  final GameCallbacks callbacks;

  // ---- Shake tuning: single source of truth (design asks for one place). ----
  static const double shakeDurationDefault = 0.16; // 160ms
  static const double shakeMagnitudeLight = 5;
  static const double shakeMagnitudeHeavy = 10;

  late final IsoProjection iso;
  late final PathSystem path;
  late final WaveSpawner spawner;
  late final ZoneTheme theme;
  late final CoreComponent core;

  late final PositionComponent worldRoot;

  // ---- Live run state ----
  double mw = 0;
  double coreIntegrity = 0;
  double integrityMax = 0;
  double damageTaken = 0;
  int waveNumber = 0;
  double elapsed = 0;
  int score = 0;
  RunPhase phase = RunPhase.building;
  bool bossActive = false;

  final List<EnemyComponent> enemies = [];
  final Map<TileCoord, PositionComponent> _occupied = {};
  final Map<TileCoord, TowerComponent> _slowTowers = {};

  /// Set from the HUD build tray; null == inspect/select mode.
  TowerType? selectedBuild;
  TileCoord? _selectedCoord;

  Vector2 _baseOffset = Vector2.zero();
  double _scale = 1;
  double _shakeTime = 0;
  double _shakeMag = 0;
  double _snapshotTimer = 0;
  final math.Random _rng = math.Random();

  @override
  Color backgroundColor() => const Color(0xFFF7F9FC);

  @override
  Future<void> onLoad() async {
    iso = IsoProjection(tileWidth: 64);
    path = PathSystem(config.path);
    theme = ZoneTheme.forZone(config.zone);

    mw = config.startingMw.toDouble();
    coreIntegrity = config.coreIntegrity;
    integrityMax = config.coreIntegrity;

    worldRoot = PositionComponent();
    add(worldRoot);

    _buildBoard();

    spawner = WaveSpawner(
      config.waves,
      onSpawn: _spawnEnemy,
      onWaveStart: _onWaveStart,
    );

    _recenter();
    _publishSnapshot(force: true);
  }

  void _buildBoard() {
    final pathTiles = path.pathTiles;
    for (var r = 0; r < config.gridRows; r++) {
      for (var c = 0; c < config.gridCols; c++) {
        final coord = TileCoord(c, r);
        TileKind kind = TileKind.ground;
        if (coord == config.spawnTile) {
          kind = TileKind.spawn;
        } else if (coord == config.coreTile) {
          kind = TileKind.core;
        } else if (pathTiles.contains(coord)) {
          kind = TileKind.path;
        } else if (config.safeZones.contains(coord)) {
          kind = TileKind.safeZone;
        }
        final even = (c + r).isEven;
        worldRoot.add(GroundTile(
          tile: Vector2(c.toDouble(), r.toDouble()),
          kind: kind,
          fill: even ? theme.ground : theme.groundAlt,
          edge: const Color(0x22000000),
          accent: theme.accent,
        ));
      }
    }

    core = CoreComponent(
      tile: Vector2(
          config.coreTile.col.toDouble(), config.coreTile.row.toDouble()),
      accent: theme.accent,
    );
    worldRoot.add(core);
  }

  void _recenter() {
    if (size.x == 0 || size.y == 0) return;
    final gridCenter = iso.tileToScreen(
        config.gridCols / 2, config.gridRows / 2);
    final bounds = iso.worldBounds(config.gridCols, config.gridRows);
    const pad = 40.0;
    final scaleX = (size.x - pad) / bounds.width;
    // Reserve the top third for the HUD by fitting into ~70% of height.
    final scaleY = (size.y * 0.72 - pad) / bounds.height;
    _scale = math.min(scaleX, scaleY).clamp(0.4, 2.5);

    worldRoot.scale = Vector2.all(_scale);
    _baseOffset = Vector2(size.x / 2, size.y * 0.56) - gridCenter * _scale;
    worldRoot.position = _baseOffset.clone();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _recenter();
  }

  // ---- Public control ----

  /// Begins wave spawning; called by the HUD "Start Defense" button.
  void startWaves() {
    if (phase != RunPhase.building) return;
    phase = RunPhase.inProgress;
    _publishSnapshot(force: true);
  }

  bool get isBuilding => phase == RunPhase.building;

  /// Rewarded-ad "Continue": restore the core to half integrity and resume.
  void reviveCore() {
    if (phase != RunPhase.lost) return;
    coreIntegrity = integrityMax * 0.5;
    phase = RunPhase.inProgress;
    _publishSnapshot(force: true);
  }

  void setBuildSelection(TowerType? type) {
    selectedBuild = type;
    if (type != null) _clearSelection();
  }

  void upgradeSelected() {
    final coord = _selectedCoord;
    if (coord == null) return;
    final comp = _occupied[coord];
    int? cost;
    if (comp is TowerComponent && comp.canUpgrade) cost = comp.upgradeCost;
    if (comp is PvPanelComponent && comp.canUpgrade) cost = comp.upgradeCost;
    if (cost == null || !_spendMw(cost)) return;
    if (comp is TowerComponent) comp.upgrade();
    if (comp is PvPanelComponent) comp.upgrade();
    _emitSfx(Sfx.towerPlace);
    _selectStructure(coord); // refresh panel
  }

  // ---- Update loop ----

  @override
  void update(double dt) {
    super.update(dt);

    if (phase == RunPhase.inProgress) {
      elapsed += dt;
      spawner.tick(dt);
      _checkWin();
    }

    _decayShake(dt);

    _snapshotTimer += dt;
    if (_snapshotTimer >= 0.1) {
      _snapshotTimer = 0;
      _publishSnapshot();
    }
  }

  void _decayShake(double dt) {
    if (_shakeTime > 0) {
      _shakeTime = (_shakeTime - dt).clamp(0, 1);
      final k = _shakeTime <= 0 ? 0.0 : _shakeMag * (_shakeTime / shakeDurationDefault);
      worldRoot.position = _baseOffset +
          Vector2((_rng.nextDouble() - 0.5) * 2 * k,
              (_rng.nextDouble() - 0.5) * 2 * k);
    } else {
      worldRoot.position = _baseOffset.clone();
    }
  }

  void addShake(double magnitude) {
    _shakeTime = shakeDurationDefault;
    _shakeMag = magnitude;
    callbacks.onShake?.call(magnitude);
  }

  // ---- Input ----

  /// Handle a tap at a screen point (in game/widget logical coordinates).
  /// Called from the Flutter [GestureDetector] wrapping the game widget, which
  /// keeps input handling independent of Flame's evolving event mixins.
  void handleTapAt(Vector2 screenPoint) {
    final local = (screenPoint - _baseOffset) / _scale;
    final coord = iso.screenToTileCoord(
        local.x, local.y, config.gridCols, config.gridRows);
    if (coord == null) {
      _clearSelection();
      return;
    }
    if (selectedBuild != null) {
      _tryPlace(selectedBuild!, coord);
    } else if (_occupied.containsKey(coord)) {
      _selectStructure(coord);
    } else {
      _clearSelection();
    }
  }

  void _tryPlace(TowerType type, TileCoord coord) {
    if (_occupied.containsKey(coord)) return;
    if (phase == RunPhase.won || phase == RunPhase.lost) return;
    final spec = TowerCatalog.of(type);

    final onPath = path.isOnPath(coord);
    final isSafe = config.safeZones.contains(coord);
    final isEndpoint =
        coord == config.spawnTile || coord == config.coreTile;

    bool allowed;
    switch (spec.placeableOn) {
      case TilePlacement.path:
        allowed = onPath && !isEndpoint;
        break;
      case TilePlacement.safeZone:
        allowed = isSafe;
        break;
      case TilePlacement.any:
        allowed = !isEndpoint;
        break;
    }
    if (!allowed) return;
    if (!_spendMw(spec.tier(0).cost)) return;

    late final PositionComponent comp;
    if (spec.category == TowerCategory.economy) {
      comp = PvPanelComponent(spec: spec, coord: coord);
    } else {
      final tower = TowerComponent(spec: spec, coord: coord);
      if (spec.category == TowerCategory.slow) _slowTowers[coord] = tower;
      comp = tower;
    }
    worldRoot.add(comp);
    _occupied[coord] = comp;
    _emitSfx(Sfx.towerPlace);
    _publishSnapshot(force: true);
  }

  void _selectStructure(TileCoord coord) {
    _selectedCoord = coord;
    final comp = _occupied[coord];
    String name = '';
    int tier = 0, maxTier = 0;
    int? cost;
    if (comp is TowerComponent) {
      name = comp.spec.name;
      tier = comp.tier;
      maxTier = comp.spec.maxTier;
      cost = comp.upgradeCost;
    } else if (comp is PvPanelComponent) {
      name = comp.spec.name;
      tier = comp.tier;
      maxTier = comp.spec.maxTier;
      cost = comp.upgradeCost;
    }
    callbacks.onSelection?.call(SelectedStructure(
      coord: coord,
      name: name,
      tier: tier,
      maxTier: maxTier,
      upgradeCost: cost,
    ));
  }

  void _clearSelection() {
    _selectedCoord = null;
    callbacks.onSelection?.call(null);
  }

  // ---- Component-facing API ----

  double slowMultiplierAt(TileCoord tile) =>
      _slowTowers[tile]?.currentTier.slowMultiplier ?? 1.0;

  void addMw(int amount) => mw += amount;

  bool _spendMw(int amount) {
    if (mw < amount) return false;
    mw -= amount;
    return true;
  }

  void spawnArc(Vector2 fromTile, Vector2 toTile, {required bool primary}) {
    worldRoot.add(ArcEffect(
      fromTile: fromTile,
      toTile: toTile,
      color: theme.accent,
      primary: primary,
    ));
  }

  void spawnFloatingText(String text, Vector2 tile, Color color) {
    worldRoot.add(FloatingText(text: text, tile: tile, color: color));
  }

  void onTowerFired() => _emitSfx(Sfx.towerFire);

  void onChainHit() {
    addShake(shakeMagnitudeLight);
    _emitSfx(Sfx.towerFire);
  }

  void onEnemyKilled(EnemyComponent e) {
    enemies.remove(e);
    addMw(e.spec.mwReward);
    score += (e.spec.mwReward * 1.5).round();
    _emitSfx(Sfx.enemyDeath);
  }

  void onEnemyReachedCore(EnemyComponent e) {
    enemies.remove(e);
    coreIntegrity = (coreIntegrity - e.spec.coreDamage).clamp(0, integrityMax);
    damageTaken += e.spec.coreDamage;
    core.flashDamage();
    addShake(e.spec.category == EnemyCategory.malware
        ? shakeMagnitudeHeavy
        : shakeMagnitudeLight);
    _emitSfx(Sfx.coreDamage);
    if (coreIntegrity <= 0 && phase == RunPhase.inProgress) {
      _finish(false);
    }
  }

  // ---- Wave callbacks ----

  void _spawnEnemy(EnemyType type, double healthScale, double speedScale) {
    final spec = EnemyCatalog.of(type);
    final e = EnemyComponent(
      spec: spec,
      maxHealth: spec.baseHealth * healthScale,
      speed: spec.baseSpeed * speedScale,
    );
    enemies.add(e);
    worldRoot.add(e);
  }

  void _onWaveStart(int number, bool isBoss) {
    waveNumber = number;
    bossActive = isBoss;
    if (isBoss) addShake(shakeMagnitudeHeavy);
    _emitSfx(Sfx.waveStart);
    _publishSnapshot(force: true);
  }

  // ---- Win / lose ----

  void _checkWin() {
    if (phase != RunPhase.inProgress) return;
    if (spawner.allSpawned && enemies.isEmpty && coreIntegrity > 0) {
      _finish(true);
    }
  }

  void _finish(bool won) {
    if (phase == RunPhase.won || phase == RunPhase.lost) return;
    phase = won ? RunPhase.won : RunPhase.lost;
    _emitSfx(won ? Sfx.levelWin : Sfx.levelLose);
    _publishSnapshot(force: true);

    final stars = _computeStars(won);
    final baseCredits = won ? _computeCredits(stars) : 0;
    callbacks.onFinished(LevelResult(
      levelId: config.id,
      stars: stars,
      baseGridCredits: baseCredits,
      mwEarned: mw.round(),
      timeSeconds: elapsed,
      integrityRemaining: coreIntegrity,
    ));
  }

  StarRating _computeStars(bool won) {
    if (!won) return StarRating.none;
    final lostFraction = damageTaken / integrityMax;
    return StarRating(
      survived: true,
      lowDamage: lostFraction <= config.lowDamageStarThreshold,
      fastEnough: elapsed <= config.timeStarThreshold,
    );
  }

  int _computeCredits(StarRating stars) {
    // Base reward scales with level and stars earned.
    return 20 + config.id * 3 + stars.count * 10;
  }

  // ---- Snapshots / SFX ----

  void _publishSnapshot({bool force = false}) {
    callbacks.onSnapshot(LevelState(
      levelId: config.id,
      mw: mw.round(),
      coreIntegrity: coreIntegrity,
      maxCoreIntegrity: integrityMax,
      waveNumber: waveNumber,
      totalWaves: spawner.totalWaves,
      phase: phase,
      elapsedSeconds: elapsed,
      score: score,
      bossWaveActive: bossActive,
    ));
  }

  void _emitSfx(Sfx sfx) => callbacks.onSfx?.call(sfx);
}
