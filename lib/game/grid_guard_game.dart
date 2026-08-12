import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../data/dc_workload.dart';
import '../data/enemy_catalog.dart';
import '../data/tower_catalog.dart';
import '../data/zone_theme.dart';
import '../models/enemy_type.dart';
import '../models/level_config.dart';
import '../models/level_state.dart';
import '../models/star_rating.dart';
import '../models/tower_type.dart';
import 'components/arc_effect.dart';
import 'components/burst_effect.dart';
import 'components/core_component.dart';
import 'components/enemy_component.dart';
import 'components/facility_component.dart';
import 'components/floating_text.dart';
import 'components/ground_tile.dart';
import 'components/night_overlay.dart';
import 'components/wind_turbine_component.dart';
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

/// One staggered enemy emission queued by the endless raid director.
class _PendingSpawn {
  _PendingSpawn(this.time, this.type, this.healthScale, this.speedScale);
  double time;
  final EnemyType type;
  final double healthScale;
  final double speedScale;
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

  /// Real unit sprites keyed by asset name (e.g. 'pv_panel'), each a list of 3
  /// tier frames sliced from a horizontal strip. A key is absent when the file
  /// isn't present, so components fall back to procedural drawing per unit.
  final Map<String, List<Sprite>> sprites = {};

  List<Sprite>? spritesFor(String key) => sprites[key];

  late final PositionComponent worldRoot;

  // ---- Live run state (real energy-flow economy) ----
  // Energy is the operational fuel: PV produces it, the BESS stores it, and the
  // Data Center + firing towers consume it. Money is the build/upgrade currency,
  // earned by the Data Center while it stays powered. Score comes from kills.
  double energy = 0;
  double money = 0;
  bool dcPowered = false;

  double coreIntegrity = 0;
  double integrityMax = 0;
  double damageTaken = 0;
  int waveNumber = 0;
  double elapsed = 0;
  int score = 0;
  RunPhase phase = RunPhase.building;
  bool bossActive = false;

  final List<EnemyComponent> enemies = [];
  final List<PvPanelComponent> pvPanels = [];
  final List<WindTurbineComponent> windTurbines = [];
  final List<FacilityComponent> bessUnits = [];
  final List<FacilityComponent> dataCenters = [];
  final Map<TileCoord, PositionComponent> _occupied = {};
  final Map<TileCoord, TowerComponent> _slowTowers = {};

  /// Total battery capacity: a small base plus every placed BESS unit.
  double get energyCapacity =>
      config.bessCapacity +
      bessUnits.fold(0.0, (s, u) => s + u.currentTier.capacity);

  /// Combined Data-Center power (sum of dcPower across placed DCs).
  double get dcTotalPower =>
      dataCenters.fold(0.0, (s, u) => s + u.currentTier.dcPower);

  int get dataCenterCount => dataCenters.length;

  /// Total PV output (energy/sec) from every placed panel.
  /// Raw combined nameplate output of all PV panels (before sunlight).
  double get pvOutput =>
      pvPanels.fold(0.0, (s, p) => s + p.currentTier.mwPerSecond);

  /// Time of day in [0,1): 0 = midnight, 0.25 = sunrise, 0.5 = noon,
  /// 0.75 = sunset. Advances continuously through the run.
  double timeOfDay = 0;

  /// Solar irradiance factor in [0,1]: 0 at night, peaking at noon. PV only
  /// produces in daylight, so the BESS must carry the grid through the night.
  double get sunFactor {
    final s = math.sin(2 * math.pi * (timeOfDay - 0.25));
    return s < 0 ? 0.0 : s;
  }

  bool get isNight => sunFactor <= 0.02;

  /// Actual PV output right now (nameplate scaled by sunlight).
  double get effectivePvOutput => pvOutput * sunFactor;

  /// Combined nameplate output of all wind turbines (before wind).
  double get windOutput =>
      windTurbines.fold(0.0, (s, w) => s + w.currentTier.mwPerSecond);

  /// Wind strength in [0.15,1.0], oscillating over time. Works day AND night —
  /// wind is what carries the grid when the sun is down.
  double windFactor = 0.6;
  double _windPhase = 0;

  double get effectiveWindOutput => windOutput * windFactor;

  /// Total energy generated right now (solar + wind).
  double get generation => effectivePvOutput + effectiveWindOutput;

  /// The Data Center's current workload — sets income, draw and threat.
  int workloadIndex = 0;
  DcWorkload get workload => DcWorkloadCatalog.workloads[workloadIndex];

  /// Base security rating from placed defences: Shock Transformers count double
  /// (they're the real deterrent), Scissor Barriers count single; both scale
  /// with tier. High-value workloads gate on this.
  int get securityRating {
    var s = 0;
    for (final c in _occupied.values) {
      if (c is TowerComponent) {
        if (c.spec.category == TowerCategory.damage) {
          s += (c.tier + 1) * 2;
        } else if (c.spec.category == TowerCategory.slow) {
          s += c.tier + 1;
        }
      }
    }
    return s;
  }

  /// Switches the DC workload, but only if the base meets its security
  /// requirement — you can't take a bank/government contract unguarded.
  void setWorkload(int index) {
    final i = index.clamp(0, DcWorkloadCatalog.workloads.length - 1);
    if (securityRating < DcWorkloadCatalog.workloads[i].requiredSecurity) return;
    workloadIndex = i;
    _publishSnapshot(force: true);
  }

  /// Total Data Center energy draw per second (workload × total DC power).
  double get dcDraw => workload.draw * dcTotalPower;

  /// Total money earned per second while powered (workload × total DC power).
  double get dcIncome => workload.income * dcTotalPower;

  /// How hot the base runs — scales raid frequency and size.
  double get threatMultiplier => workload.threat;

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

    await _loadSprites();

    money = config.startMoney.toDouble();
    energy = config.startEnergy;
    timeOfDay = config.startTimeOfDay;
    coreIntegrity = config.coreIntegrity;
    integrityMax = config.coreIntegrity;

    worldRoot = PositionComponent();
    add(worldRoot);
    add(NightOverlay());

    _buildBoard();

    spawner = WaveSpawner(
      config.waves,
      onSpawn: _spawnEnemy,
      onWaveStart: _onWaveStart,
    );

    _recenter();
    _publishSnapshot(force: true);
  }

  /// Loads any available unit art. Each file (e.g. assets/images/pv_panel.png)
  /// is a horizontal strip of 3 tier frames; a missing file is simply skipped
  /// and that unit keeps its procedural look.
  Future<void> _loadSprites() async {
    const keys = [
      'pv_panel',
      'wind_turbine',
      'scissor_barrier',
      'shock_transformer',
    ];
    for (final key in keys) {
      try {
        final img = await images.load('$key.png');
        final fw = img.width / 3;
        final fh = img.height.toDouble();
        sprites[key] = [
          for (var i = 0; i < 3; i++)
            Sprite(img,
                srcPosition: Vector2(i * fw, 0), srcSize: Vector2(fw, fh)),
        ];
      } catch (_) {
        // No art for this unit yet — fine, it stays procedural.
      }
    }

    // Single-frame structures (no tiers): the Data Center (core) and BESS.
    for (final key in ['core', 'bess']) {
      try {
        sprites[key] = [Sprite(await images.load('$key.png'))];
      } catch (_) {/* stays procedural */}
    }
  }

  void _buildBoard() {
    final pathTiles = path.pathTiles;
    // A single ground tone (no checker) with a darker "lane" tone for the route.
    final road = Color.lerp(theme.ground, const Color(0xFF1A2230), 0.16)!;
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
        worldRoot.add(GroundTile(
          tile: Vector2(c.toDouble(), r.toDouble()),
          kind: kind,
          fill: theme.ground,
          road: road,
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
    if (comp is WindTurbineComponent && comp.canUpgrade) cost = comp.upgradeCost;
    if (comp is FacilityComponent && comp.canUpgrade) cost = comp.upgradeCost;
    if (cost == null || !_spendMoney(cost)) return;
    if (comp is TowerComponent) comp.upgrade();
    if (comp is PvPanelComponent) comp.upgrade();
    if (comp is WindTurbineComponent) comp.upgrade();
    if (comp is FacilityComponent) comp.upgrade();
    _emitSfx(Sfx.towerPlace);
    _selectStructure(coord); // refresh panel
  }

  // ---- Update loop ----

  @override
  void update(double dt) {
    super.update(dt);

    if (phase != RunPhase.won && phase != RunPhase.lost) {
      _tickEconomy(dt);
    }

    if (phase == RunPhase.inProgress) {
      elapsed += dt;
      if (config.endless) {
        _tickRaids(dt);
      } else {
        spawner.tick(dt);
        _checkWin();
      }
    }

    _decayShake(dt);

    _snapshotTimer += dt;
    if (_snapshotTimer >= 0.1) {
      _snapshotTimer = 0;
      _publishSnapshot();
    }
  }

  /// The energy-flow simulation, ticked every frame while the run is live.
  ///
  /// PV output charges the BESS (capped at capacity). The Data Center then tries
  /// to draw its power: if the BESS can cover it, the DC runs and earns money;
  /// otherwise it idles (no income) until energy recovers. Towers draw energy
  /// separately, per shot, via [tryDrawEnergy].
  void _tickEconomy(double dt) {
    // 0) Advance the day/night clock and the wind.
    timeOfDay = (timeOfDay + dt / config.dayLength) % 1.0;
    _windPhase += dt;
    windFactor = (0.55 +
            0.35 * math.sin(_windPhase * 0.35) +
            0.15 * math.sin(_windPhase * 1.1))
        .clamp(0.15, 1.0);

    // 1) Solar + wind charge the battery (solar needs daylight; wind doesn't).
    energy = (energy + generation * dt).clamp(0, energyCapacity);

    // 2) Data Centers consume to run, and pay out while powered.
    final draw = dcDraw * dt;
    if (dcTotalPower > 0 && energy >= draw) {
      energy -= draw;
      money += dcIncome * dt;
      dcPowered = true;
    } else {
      dcPowered = false;
    }
  }

  /// Towers call this to spend energy on a shot. Returns false (don't fire) when
  /// the BESS is too low — that's how starving the grid makes defences fail.
  bool tryDrawEnergy(double amount) {
    if (energy >= amount) {
      energy -= amount;
      return true;
    }
    return false;
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
    if (!_spendMoney(spec.tier(0).cost)) return;

    late final PositionComponent comp;
    switch (spec.category) {
      case TowerCategory.economy:
        if (spec.type == TowerType.windTurbine) {
          final w = WindTurbineComponent(spec: spec, coord: coord);
          windTurbines.add(w);
          comp = w;
        } else {
          final pv = PvPanelComponent(spec: spec, coord: coord);
          pvPanels.add(pv);
          comp = pv;
        }
        break;
      case TowerCategory.storage:
        final b = FacilityComponent(
            spec: spec, coord: coord, spriteKey: 'bess', widthTiles: 1.6);
        bessUnits.add(b);
        comp = b;
        break;
      case TowerCategory.datacenter:
        final d = FacilityComponent(
            spec: spec, coord: coord, spriteKey: 'core', widthTiles: 1.9);
        dataCenters.add(d);
        comp = d;
        break;
      case TowerCategory.slow:
      case TowerCategory.damage:
        final tower = TowerComponent(spec: spec, coord: coord);
        if (spec.category == TowerCategory.slow) _slowTowers[coord] = tower;
        comp = tower;
        break;
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
    } else if (comp is WindTurbineComponent) {
      name = comp.spec.name;
      tier = comp.tier;
      maxTier = comp.spec.maxTier;
      cost = comp.upgradeCost;
    } else if (comp is FacilityComponent) {
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

  /// Radius (in tiles) of a Scissor Barrier's slow field. Kept in sync with the
  /// visual field drawn on the barrier.
  static const double barrierSlowRadius = 1.5;

  /// Strongest slow affecting a fractional board position: any barrier whose
  /// field ([barrierSlowRadius]) covers [pos] slows enemies there. Applying it
  /// over an area (not a single tile) is what makes the barrier bite and bunch
  /// enemies up for the Shock Transformer's chain.
  double slowMultiplierAt(Vector2 pos) {
    var m = 1.0;
    for (final b in _slowTowers.values) {
      if ((pos - b.tile).length <= barrierSlowRadius) {
        final s = b.currentTier.slowMultiplier;
        if (s < m) m = s;
      }
    }
    return m;
  }

  bool _spendMoney(int amount) {
    if (money < amount) return false;
    money -= amount;
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
    // Kills award SCORE only — not energy, not money. Money comes from the Data
    // Center; energy comes from PV.
    score += e.spec.scoreValue;
    worldRoot.add(BurstEffect(tile: e.tile.clone(), color: e.spec.tint));
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

  // ---- Endless raid director ----

  double _raidTimer = 12; // first raid delay after START
  int raidCount = 0;
  final List<_PendingSpawn> _pendingSpawns = [];

  void _tickRaids(double dt) {
    // Drain staggered spawns from the current raid.
    for (final p in _pendingSpawns) {
      p.time -= dt;
    }
    while (_pendingSpawns.isNotEmpty && _pendingSpawns.first.time <= 0) {
      final p = _pendingSpawns.removeAt(0);
      _spawnEnemy(p.type, p.healthScale, p.speedScale);
    }

    _raidTimer -= dt;
    if (_raidTimer <= 0) {
      _launchRaid();
      // Higher-value workloads run hotter: raids come faster (down to ~8s).
      _raidTimer =
          math.max(8.0, (26.0 - raidCount * 0.5) / threatMultiplier);
    }
  }

  void _launchRaid() {
    raidCount++;
    final n = raidCount;
    final threat = threatMultiplier;
    final hs = 1.0 + n * 0.10;
    final ss = 1.0 + n * 0.02;
    final drones = ((4 + n * 2) * threat).round();
    final malware = ((n / 3) * threat).floor();
    var t = 0.0;
    for (var i = 0; i < drones; i++) {
      _pendingSpawns.add(
          _PendingSpawn(t, EnemyType.saboteurDrone, hs, ss));
      t += 0.45;
    }
    for (var i = 0; i < malware; i++) {
      _pendingSpawns.add(
          _PendingSpawn(t, EnemyType.malwareCrawler, hs, ss));
      t += 0.9;
    }
    waveNumber = n;
    bossActive = n % 5 == 0;
    if (bossActive) addShake(shakeMagnitudeHeavy);
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
      finalScore: score,
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
      energy: energy,
      energyCapacity: energyCapacity,
      money: money.floor(),
      score: score,
      generation: generation,
      dcDraw: dcDraw,
      dcIncome: dcIncome,
      dcPowered: dcPowered,
      sunFactor: sunFactor,
      windFactor: windFactor,
      isNight: isNight,
      dataCenterCount: dataCenterCount,
      workloadIndex: workloadIndex,
      security: securityRating,
      coreIntegrity: coreIntegrity,
      maxCoreIntegrity: integrityMax,
      waveNumber: waveNumber,
      totalWaves: spawner.totalWaves,
      phase: phase,
      elapsedSeconds: elapsed,
      endless: config.endless,
      bossWaveActive: bossActive,
    ));
  }

  void _emitSfx(Sfx sfx) => callbacks.onSfx?.call(sfx);
}
