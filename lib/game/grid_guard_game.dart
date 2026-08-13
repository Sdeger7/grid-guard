import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../data/dc_workload.dart';
import '../data/enemy_catalog.dart';
import '../data/premium_packages.dart';
import '../data/tower_catalog.dart';
import '../data/zone_theme.dart';
import '../models/enemy_type.dart';
import '../models/base_save.dart';
import '../models/level_config.dart';
import '../models/level_state.dart';
import '../models/star_rating.dart';
import '../models/tower_type.dart';
import 'components/arc_effect.dart';
import 'components/burst_effect.dart';
import 'components/core_component.dart';
import 'components/drone_bay_component.dart';
import 'components/enemy_component.dart';
import 'components/facility_component.dart';
import 'components/floating_text.dart';
import 'components/ground_tile.dart';
import 'components/night_overlay.dart';
import 'components/wind_turbine_component.dart';
import 'components/pv_panel_component.dart';
import 'components/structure_component.dart';
import 'components/tower_component.dart';
import 'systems/iso.dart';
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
    this.healthFraction = 1.0,
    this.repairCost = 0,
    this.isOffline = false,
  });
  final TileCoord coord;
  final String name;
  final int tier;
  final int maxTier;
  final int? upgradeCost;

  /// Condition of the selected building and what a repair would cost.
  final double healthFraction;
  final int repairCost;
  final bool isOffline;

  bool get needsRepair => repairCost > 0;
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
  GridGuardGame({
    required this.config,
    required this.callbacks,
    this.perks = const PremiumPackage(
        id: '_none', name: '', emoji: '', price: 0, blurb: ''),
    this.initialBase,
  });

  final LevelConfig config;
  final GameCallbacks callbacks;

  /// Combined premium perks the player owns, applied to this run.
  final PremiumPackage perks;

  /// A previously saved base to rebuild on load, if there is one. Survival is
  /// one continuous site, not a fresh run each time the app opens.
  final BaseSave? initialBase;

  // ---- Shake tuning: single source of truth (design asks for one place). ----
  static const double shakeDurationDefault = 0.16; // 160ms
  static const double shakeMagnitudeLight = 5;
  static const double shakeMagnitudeHeavy = 10;

  late final IsoProjection iso;
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
  final List<DroneBayComponent> droneBays = [];
  final Map<TileCoord, PositionComponent> _occupied = {};
  final Map<TileCoord, TowerComponent> _slowTowers = {};

  /// Total battery capacity: a small base plus every placed BESS unit.
  double get energyCapacity =>
      config.bessCapacity +
      perks.capacityBonus +
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
  /// 0.75 = sunset. Advances continuously through the run. A run opens just
  /// after sunrise so the first thing the player gets is a full day to build,
  /// not a raid.
  double timeOfDay = 0.28;

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
      } else if (c is DroneBayComponent) {
        // Active air cover counts as strongly as a transformer.
        s += (c.tier + 1) * 2;
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
  double get dcIncome =>
      workload.income * dcTotalPower * perks.incomeMultiplier;

  /// Heat actually being applied right now. Switching to a hotter contract
  /// doesn't summon a maximum raid on the spot — word gets out over about a
  /// minute, which is the window the player uses to build defences before the
  /// new attention arrives.
  double _threatRamp = DcWorkloadCatalog.workloads.first.threat;

  /// How fast heat catches up with the current contract, per second.
  static const double threatRampRate = 0.025;

  /// How hot the base runs — scales raid frequency and size.
  double get threatMultiplier => _threatRamp * growthThreat;

  /// Where heat is heading, so the HUD can warn before it lands.
  double get targetThreatMultiplier => workload.threat * growthThreat;

  /// Set from the HUD build tray; null == inspect/select mode.
  TowerType? selectedBuild;
  TileCoord? _selectedCoord;

  /// Scale that fits the whole grid on screen. The view the player actually
  /// sees is this times [_zoom], shifted by [_pan] — so pinching and dragging
  /// never fight the fit logic, and a resize recomputes the fit while keeping
  /// whatever zoom the player chose.
  double _fitScale = 1;
  double _zoom = 1;
  Vector2 _pan = Vector2.zero();

  static const double minZoom = 0.7;
  static const double maxZoom = 3.5;

  double get _scale => _fitScale * _zoom;

  /// Where the world's origin sits on screen at the current zoom, before pan.
  Vector2 get _fitOrigin {
    final gridCenter =
        iso.tileToScreen(config.gridCols / 2, config.gridRows / 2);
    return Vector2(size.x / 2, size.y * 0.56) - gridCenter * _scale;
  }

  Vector2 get _baseOffset => _fitOrigin + _pan;

  double _shakeTime = 0;
  double _shakeMag = 0;
  double _snapshotTimer = 0;
  final math.Random _rng = math.Random();

  @override
  Color backgroundColor() => const Color(0xFF3E6B39);

  @override
  Future<void> onLoad() async {
    iso = IsoProjection(tileWidth: 64);
    theme = ZoneTheme.forZone(config.zone);

    await _loadSprites();

    money = config.startMoney + perks.startMoneyBonus.toDouble();
    integrityMax = config.coreIntegrity + perks.startCoreBonus;
    coreIntegrity = integrityMax;
    timeOfDay = config.startTimeOfDay;
    energy = math.min(config.startEnergy + perks.startEnergyBonus,
        config.bessCapacity + perks.capacityBonus);

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

    final saved = initialBase;
    if (saved != null && !saved.isEmpty) {
      restoreSave(saved);
    }
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
      'kule', // Shock Transformer (3 tiers)
      'sabodrone', // Saboteur Drone (3 sizes, by raid scaling)
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

  /// The base's tile (map centre), as integer coordinates.
  TileCoord get baseCoord =>
      TileCoord(config.gridCols ~/ 2, config.gridRows ~/ 2);

  void _buildBoard() {
    // Open yard: every tile is plain buildable ground — no lanes, no pads. The
    // base sits at the centre and raids fly in from every edge.
    final road = Color.lerp(theme.ground, const Color(0xFF1A2230), 0.16)!;
    for (var r = 0; r < config.gridRows; r++) {
      for (var c = 0; c < config.gridCols; c++) {
        final coord = TileCoord(c, r);
        worldRoot.add(GroundTile(
          tile: Vector2(c.toDouble(), r.toDouble()),
          kind: coord == baseCoord ? TileKind.core : TileKind.ground,
          fill: theme.ground,
          road: road,
          accent: theme.accent,
        )..isEdge = c == 0 ||
            r == 0 ||
            c == config.gridCols - 1 ||
            r == config.gridRows - 1);
      }
    }

    core = CoreComponent(
      tile: Vector2(baseCoord.col.toDouble(), baseCoord.row.toDouble()),
      accent: theme.accent,
    );
    worldRoot.add(core);
  }

  void _recenter() {
    if (size.x == 0 || size.y == 0) return;
    final bounds = iso.worldBounds(config.gridCols, config.gridRows);
    const pad = 40.0;
    final scaleX = (size.x - pad) / bounds.width;
    // Reserve the top third for the HUD by fitting into ~70% of height.
    final scaleY = (size.y * 0.72 - pad) / bounds.height;
    _fitScale = math.min(scaleX, scaleY).clamp(0.4, 2.5);
    _applyView();
  }

  void _applyView() {
    worldRoot.scale = Vector2.all(_scale);
    worldRoot.position = _baseOffset.clone();
  }

  /// Pinch-to-zoom about [focal] (a point in widget coordinates), so the tile
  /// under the player's fingers stays put instead of sliding away.
  void zoomBy(double factor, Vector2 focal) {
    final before = _scale;
    final world = (focal - _baseOffset) / before;
    _zoom = (_zoom * factor).clamp(minZoom, maxZoom);
    // Re-derive the pan that keeps [world] under [focal] at the new scale.
    _pan = focal - world * _scale - _fitOrigin;
    _clampPan();
    _applyView();
  }

  /// Drag the map. [delta] is a screen-space movement.
  void panBy(Vector2 delta) {
    _pan += delta;
    _clampPan();
    _applyView();
  }

  /// Snap back to the fitted, centred view.
  void resetView() {
    _zoom = 1;
    _pan = Vector2.zero();
    _applyView();
  }

  /// Keeps the grid from being dragged entirely off screen.
  void _clampPan() {
    final bounds = iso.worldBounds(config.gridCols, config.gridRows);
    final limitX = bounds.width * _scale * 0.5 + size.x * 0.25;
    final limitY = bounds.height * _scale * 0.5 + size.y * 0.25;
    _pan = Vector2(
      _pan.x.clamp(-limitX, limitX),
      _pan.y.clamp(-limitY, limitY),
    );
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
    if (comp is! StructureComponent || !comp.canUpgrade) return;
    final cost = comp.upgradeCost;
    if (cost == null || !_spendMoney(cost)) return;
    comp.upgrade();
    _emitSfx(Sfx.towerPlace);
    _selectStructure(coord);
    _publishSnapshot(force: true);
  }

  // ---- Update loop ----

  @override
  void update(double dt) {
    super.update(dt);

    if (phase != RunPhase.won && phase != RunPhase.lost) {
      _tickEconomy(dt);
      _tickCoins(dt);
    }

    if (phase == RunPhase.inProgress) {
      elapsed += dt;
      if (config.endless) {
        _tickThreatRamp(dt);
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

    // 2) Data Centers consume to run, and pay out while powered — but they only
    //    get what's above the defence reserve, so a greedy workload can't starve
    //    the towers and leave the base defenceless.
    final draw = dcDraw * dt;
    final spare = energy - defenceReserve;
    if (dcTotalPower > 0 && spare >= draw) {
      energy -= draw;
      money += dcIncome * dt;
      dcPowered = true;
    } else {
      dcPowered = false;
    }
  }

  void _tickCoins(double dt) {
    coinsEarned += coinRate * dt;
  }

  /// Energy held back from the Data Centers so defences can always fire.
  double get defenceReserve => math.min(energyCapacity * 0.25, 25);

  // ---- Structures: damage, repair, destruction ----

  /// Every player-built structure, keyed by tile.
  Iterable<StructureComponent> get structures =>
      _occupied.values.whereType<StructureComponent>();

  /// Closest live structure to [pos] within [within] tiles — what a raider mauls.
  StructureComponent? nearestStructureTo(Vector2 pos, {double within = 2.5}) {
    StructureComponent? best;
    var bestD = within;
    for (final s in structures) {
      if (s.isDestroyed) continue;
      final d = (s.tile - pos).length;
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    return best;
  }

  /// A raider strafes a structure. Destroyed buildings are removed from the map
  /// and have to be rebuilt at full price.
  void enemyAttackStructure(EnemyComponent e, StructureComponent s) {
    final destroyed = s.takeStructureDamage(e.attackDamage);
    addShake(shakeMagnitudeLight);
    _emitSfx(Sfx.coreDamage);
    if (destroyed) {
      destroyStructure(s);
      addShake(shakeMagnitudeHeavy);
    }
    _publishSnapshot(force: true);
  }

  void destroyStructure(StructureComponent s) {
    _occupied.remove(s.coord);
    _slowTowers.remove(s.coord);
    pvPanels.remove(s);
    windTurbines.remove(s);
    bessUnits.remove(s);
    dataCenters.remove(s);
    droneBays.remove(s);
    worldRoot.add(BurstEffect(tile: s.tile.clone(), color: const Color(0xFFE23D4B)));
    s.removeFromParent();
    if (_selectedCoord == s.coord) _clearSelection();
  }

  /// Repairs the selected structure for money.
  void repairSelected() {
    final coord = _selectedCoord;
    if (coord == null) return;
    final s = _occupied[coord];
    if (s is! StructureComponent || !s.needsRepair) return;
    final cost = repairCostOf(s);
    if (cost <= 0 || !_spendMoney(cost)) return;
    s.repairFully();
    _emitSfx(Sfx.towerPlace);
    _selectStructure(coord);
    _publishSnapshot(force: true);
  }

  /// Repairs everything you can afford, cheapest first — the button you mash
  /// between raids.
  void repairAll() {
    final damaged = structures.where((s) => s.needsRepair).toList()
      ..sort((a, b) => repairCostOf(a).compareTo(repairCostOf(b)));
    for (final s in damaged) {
      final cost = repairCostOf(s);
      if (cost <= 0) continue;
      if (!_spendMoney(cost)) break;
      s.repairFully();
    }
    _emitSfx(Sfx.towerPlace);
    _publishSnapshot(force: true);
  }

  /// Repair bill after premium discounts.
  int repairCostOf(StructureComponent s) =>
      (s.repairCost * (1 - perks.repairDiscount)).ceil();

  int get totalRepairCost =>
      structures.fold(0, (sum, s) => sum + repairCostOf(s));
  int get damagedCount => structures.where((s) => s.needsRepair).length;

  // ---- Coins: earned by crypto mining, spent on premium packages ----

  /// Coins mined this run (whole coins are banked to the profile at run end).
  double coinsEarned = 0;

  /// Coins per second while a crypto workload runs powered — scales with how
  /// much Data Center capacity is pointed at it.
  double get coinRate =>
      workload.minesCoins && dcPowered ? 0.05 * dcTotalPower : 0.0;

  /// Total invested value on the board — bigger base, bigger target.
  int get baseValue {
    var v = 0;
    for (final s in structures) {
      for (var t = 0; t <= s.tier; t++) {
        v += s.spec.tier(t).cost;
      }
    }
    return v;
  }

  /// Growth itself raises the stakes: a richer base draws heavier raids on top
  /// of the workload's own threat.
  double get growthThreat => 1.0 + (baseValue / 1200.0).clamp(0.0, 1.4);

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
      _applyView();
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

    // Free placement: any empty tile works. The only reserved tile is the base
    // itself at the centre.
    if (coord == baseCoord) return;
    if (!_spendMoney(spec.tier(0).cost)) return;

    final comp = _createStructure(spec, coord, 0);
    worldRoot.add(comp);
    _occupied[coord] = comp;
    _emitSfx(Sfx.towerPlace);
    _publishSnapshot(force: true);
  }

  /// Instantiates and registers a structure without charging for it, so both
  /// placement and restoring a saved base go through one path.
  PositionComponent _createStructure(TowerSpec spec, TileCoord coord, int tier) {
    late final PositionComponent comp;
    switch (spec.category) {
      case TowerCategory.economy:
        if (spec.type == TowerType.windTurbine) {
          final w = WindTurbineComponent(spec: spec, coord: coord, tier: tier);
          windTurbines.add(w);
          comp = w;
        } else {
          final pv = PvPanelComponent(spec: spec, coord: coord, tier: tier);
          pvPanels.add(pv);
          comp = pv;
        }
        break;
      case TowerCategory.storage:
        final b = FacilityComponent(
            spec: spec,
            coord: coord,
            tier: tier,
            spriteKey: 'bess',
            widthTiles: 1.6);
        bessUnits.add(b);
        comp = b;
        break;
      case TowerCategory.datacenter:
        final d = FacilityComponent(
            spec: spec,
            coord: coord,
            tier: tier,
            spriteKey: 'core',
            widthTiles: 1.9);
        dataCenters.add(d);
        comp = d;
        break;
      case TowerCategory.droneBay:
        final bay = DroneBayComponent(spec: spec, coord: coord, tier: tier);
        droneBays.add(bay);
        comp = bay;
        break;
      case TowerCategory.slow:
      case TowerCategory.damage:
        final tower = TowerComponent(spec: spec, coord: coord, tier: tier);
        if (spec.category == TowerCategory.slow) _slowTowers[coord] = tower;
        comp = tower;
        break;
    }
    return comp;
  }

  void _selectStructure(TileCoord coord) {
    _selectedCoord = coord;
    final comp = _occupied[coord];
    if (comp is! StructureComponent) {
      callbacks.onSelection?.call(null);
      return;
    }
    callbacks.onSelection?.call(SelectedStructure(
      coord: coord,
      name: comp.spec.name,
      tier: comp.tier,
      maxTier: comp.spec.maxTier,
      upgradeCost: comp.upgradeCost,
      healthFraction: comp.healthFraction,
      repairCost: repairCostOf(comp),
      isOffline: comp.isOffline,
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
      if (config.endless) {
        _blackout();
      } else {
        _finish(false);
      }
    }
  }

  /// A survival site is never wiped. Losing the core is a blackout: the raid
  /// breaks off, the grid comes back at partial strength, and repairs cost
  /// money — expensive and demoralising, but you keep the base you built and
  /// carry on the next morning.
  void _blackout() {
    blackoutCount++;
    for (final e in List<EnemyComponent>.from(enemies)) {
      e.removeFromParent();
    }
    enemies.clear();
    _pendingSpawns.clear();
    _nightWaveTimes.clear();

    // Emergency restart costs a third of the cash on hand.
    money = (money * 0.66).floorToDouble();
    coreIntegrity = integrityMax * 0.45;
    energy = 0;

    // Skip to first light: the night is over, whatever was left of it.
    timeOfDay = 0.27;
    _wasNight = false;
    dayNumber++;
    addShake(shakeMagnitudeHeavy);
    _emitSfx(Sfx.coreDamage);
    _publishSnapshot(force: true);
  }

  // ---- Wave callbacks ----

  /// Tile position of the base (map centre) — everything converges here.
  Vector2 get baseTile =>
      Vector2((config.gridCols - 1) / 2, (config.gridRows - 1) / 2);

  /// Picks a random point just outside one of the four map edges, so raids come
  /// in from all sides rather than down a single lane.
  Vector2 _randomEdgeSpawn() {
    final cols = config.gridCols.toDouble();
    final rows = config.gridRows.toDouble();
    const pad = 1.5;
    switch (_rng.nextInt(4)) {
      case 0: // north
        return Vector2(_rng.nextDouble() * cols, -pad);
      case 1: // south
        return Vector2(_rng.nextDouble() * cols, rows - 1 + pad);
      case 2: // west
        return Vector2(-pad, _rng.nextDouble() * rows);
      default: // east
        return Vector2(cols - 1 + pad, _rng.nextDouble() * rows);
    }
  }

  void _spawnEnemy(EnemyType type, double healthScale, double speedScale) {
    final spec = EnemyCatalog.of(type);
    final e = EnemyComponent(
      spec: spec,
      maxHealth: spec.baseHealth * healthScale,
      speed: spec.baseSpeed * speedScale,
      spawn: _randomEdgeSpawn(),
      target: baseTile,
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

  // ---- Persistence: the base is permanent ----

  /// Highest day whose story beat has been read; carried through the save so a
  /// returning player never sees the same message twice.
  int storyDayShown = 0;

  /// Everything needed to put the player back exactly where they left off.
  BaseSave captureSave() {
    final list = <SavedStructure>[];
    _occupied.forEach((coord, comp) {
      if (comp is! StructureComponent) return;
      list.add(SavedStructure(
        type: comp.spec.type,
        col: coord.col,
        row: coord.row,
        tier: comp.tier,
        healthFraction: comp.healthFraction,
      ));
    });
    return BaseSave(
      structures: list,
      money: money.floor(),
      coins: coinsEarned,
      energy: energy,
      dayNumber: dayNumber,
      timeOfDay: timeOfDay,
      workloadIndex: workloadIndex,
      coreIntegrity: integrityMax <= 0 ? 1 : coreIntegrity / integrityMax,
      raidCount: raidCount,
      score: score,
      storyDayShown: storyDayShown,
      savedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Rebuilds a saved base into the live world. Called once, right after load.
  void restoreSave(BaseSave save) {
    for (final st in save.structures) {
      final coord = TileCoord(st.col, st.row);
      if (coord == baseCoord || _occupied.containsKey(coord)) continue;
      if (st.col < 0 ||
          st.row < 0 ||
          st.col >= config.gridCols ||
          st.row >= config.gridRows) {
        continue;
      }
      final spec = TowerCatalog.of(st.type);
      final comp = _createStructure(spec, coord, st.tier.clamp(0, 2));
      worldRoot.add(comp);
      _occupied[coord] = comp;
      if (comp is StructureComponent) {
        comp.restoreHealthFraction(st.healthFraction);
      }
    }

    money = save.money.toDouble();
    coinsEarned = save.coins;
    dayNumber = save.dayNumber;
    timeOfDay = save.timeOfDay;
    raidCount = save.raidCount;
    score = save.score;
    storyDayShown = save.storyDayShown;
    _wasNight = isNight;
    // Only adopt the saved workload if the restored base still qualifies for it.
    if (securityRating >=
        DcWorkloadCatalog.workloads[
                save.workloadIndex.clamp(0, DcWorkloadCatalog.workloads.length - 1)]
            .requiredSecurity) {
      workloadIndex =
          save.workloadIndex.clamp(0, DcWorkloadCatalog.workloads.length - 1);
    }
    _threatRamp = workload.threat;
    energy = save.energy.clamp(0, energyCapacity);
    coreIntegrity = (save.coreIntegrity.clamp(0.05, 1.0)) * integrityMax;
    // A restored site is already running; there is no "press start" any more.
    phase = RunPhase.inProgress;
    _publishSnapshot(force: true);
  }

  /// What the site produced while the app was closed. Offline production runs
  /// at a reduced rate and is capped, so leaving the game shut for a week isn't
  /// better than playing it — but coming back always pays something.
  OfflineReport computeOfflineEarnings(BaseSave save) {
    if (save.savedAtMs <= 0) {
      return const OfflineReport(seconds: 0, money: 0, coins: 0);
    }
    final away =
        (DateTime.now().millisecondsSinceEpoch - save.savedAtMs) / 1000.0;
    if (away <= 0) return const OfflineReport(seconds: 0, money: 0, coins: 0);

    const maxOfflineSeconds = 8 * 3600.0; // 8 hours of banked production
    const offlineRate = 0.35; // unattended sites run at a third of full pace
    final seconds = math.min(away, maxOfflineSeconds);

    // Generation has to cover the draw for the DC to have been running at all.
    final couldRun = dcTotalPower > 0 &&
        (pvOutput * 0.5 + windOutput * 0.6) >= dcDraw * 0.8;
    if (!couldRun) {
      return OfflineReport(seconds: seconds, money: 0, coins: 0);
    }

    return OfflineReport(
      seconds: seconds,
      money: (dcIncome * seconds * offlineRate).round(),
      coins: workload.minesCoins ? coinRate * seconds * offlineRate : 0.0,
    );
  }

  /// Banks an offline report the player has seen.
  void applyOfflineEarnings(OfflineReport report) {
    money += report.money;
    coinsEarned += report.coins;
    _publishSnapshot(force: true);
  }

  // ---- Endless raid director ----

  /// Raiders come at night, never in daylight. A run therefore reads as a
  /// rhythm the player can plan around — build and repair through the day,
  /// hold the line through the night — instead of a stopwatch that fires
  /// whenever. Heat buys extra waves *within* a night, not a faster clock.
  int dayNumber = 1;
  int raidCount = 0;
  bool _wasNight = false;

  /// Tonight's wave plan, for the HUD ("wave 2 of 3").
  int nightWavesTotal = 0;
  int nightWavesDone = 0;

  /// How many blackouts the site has suffered — a scar, not a game over.
  int blackoutCount = 0;

  /// Waves still to launch tonight, as delays measured from nightfall.
  final List<double> _nightWaveTimes = [];
  double _nightClock = 0;

  /// Money banked at the last dawn payout, for the HUD to celebrate.
  int lastDawnBonus = 0;

  final List<_PendingSpawn> _pendingSpawns = [];

  /// Eases applied heat toward the current contract's. Cooling off after
  /// downgrading is as gradual as heating up — dropping to Web Hosting the
  /// instant a raid launches shouldn't cancel it.
  void _tickThreatRamp(double dt) {
    final target = workload.threat;
    final step = threatRampRate * dt;
    if ((_threatRamp - target).abs() <= step) {
      _threatRamp = target;
    } else {
      _threatRamp += _threatRamp < target ? step : -step;
    }
  }

  void _tickRaids(double dt) {
    // Drain staggered spawns from the current raid.
    for (final p in _pendingSpawns) {
      p.time -= dt;
    }
    while (_pendingSpawns.isNotEmpty && _pendingSpawns.first.time <= 0) {
      final p = _pendingSpawns.removeAt(0);
      _spawnEnemy(p.type, p.healthScale, p.speedScale);
    }

    // Day/night edges drive everything.
    if (isNight && !_wasNight) {
      _onNightfall();
    } else if (!isNight && _wasNight) {
      _onDawn();
    }
    _wasNight = isNight;

    if (!isNight) return;

    _nightClock += dt;
    while (_nightWaveTimes.isNotEmpty && _nightWaveTimes.first <= _nightClock) {
      // Never stack a fresh wave onto one the player is still losing to; that
      // death spiral is what wiped whole bases at once. Push it later instead.
      if (enemies.length > 30) {
        _nightWaveTimes[0] = _nightClock + 5;
        break;
      }
      _nightWaveTimes.removeAt(0);
      _launchRaid();
    }
  }

  /// Dusk: schedule tonight's waves. Heat decides how many come, spread across
  /// the dark hours so there's always a lull to repair in.
  void _onNightfall() {
    _nightClock = 0;
    _nightWaveTimes.clear();

    final waves = (1 + (threatMultiplier / 1.1).floor()).clamp(1, 4);
    // Night is half the cycle; leave the last stretch clear so a night always
    // ends with a breather rather than a spawn.
    final nightSeconds = config.dayLength * 0.5;
    final window = nightSeconds * 0.62;
    for (var i = 0; i < waves; i++) {
      _nightWaveTimes.add(waves == 1 ? 2.0 : 2.0 + window * (i / (waves - 1)));
    }
    nightWavesTotal = waves;
    nightWavesDone = 0;
    _publishSnapshot(force: true);
  }

  /// Dawn: the night is survived. Pay for it, and roll the day over.
  void _onDawn() {
    _nightWaveTimes.clear();
    dayNumber++;
    // A survival payout that grows with the day and the contract, so pushing
    // into hotter work is worth the risk beyond the per-second income.
    lastDawnBonus =
        (25 + dayNumber * 12 * workload.threat).round();
    money += lastDawnBonus;
    if (workload.minesCoins) coinsEarned += 1.0 + dayNumber * 0.15;
    _publishSnapshot(force: true);
  }

  void _launchRaid() {
    raidCount++;
    nightWavesDone++;
    // Difficulty tracks the day, not the raid counter — otherwise a hot
    // contract that fields four waves a night would also make each of those
    // waves hit like a much later one.
    final n = dayNumber;
    final threat = threatMultiplier;
    final hs = 1.0 + n * 0.14;
    final ss = 1.0 + n * 0.03;

    // Heat buys *more waves per night* (see _onNightfall); it only partly
    // scales any single wave, and the total is capped. Multiplying the count by
    // raw threat meant a high-value contract could field ~90 drones at once and
    // flatten a whole base with no counterplay.
    final sizeFactor = 0.6 + 0.4 * threat;
    final drones = math.min(20, ((3 + n * 1.6) * sizeFactor).round());
    final malware = math.min(6, ((n / 3) * sizeFactor).floor());
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
    waveNumber = raidCount;
    // Every fifth day is a named assault — a beat the player counts toward.
    bossActive = dayNumber % 5 == 0;
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
      coins: coinsEarned,
      damagedCount: damagedCount,
      totalRepairCost: totalRepairCost,
      threat: threatMultiplier,
      threatTarget: targetThreatMultiplier,
      baseValue: baseValue,
      coreIntegrity: coreIntegrity,
      maxCoreIntegrity: integrityMax,
      waveNumber: waveNumber,
      dayNumber: dayNumber,
      nightWavesTotal: nightWavesTotal,
      nightWavesDone: nightWavesDone,
      totalWaves: spawner.totalWaves,
      phase: phase,
      elapsedSeconds: elapsed,
      endless: config.endless,
      bossWaveActive: bossActive,
    ));
  }

  void _emitSfx(Sfx sfx) => callbacks.onSfx?.call(sfx);
}
