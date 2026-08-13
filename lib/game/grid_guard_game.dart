import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../data/abilities.dart';
import '../data/dc_workload.dart';
import '../data/enemy_catalog.dart';
import '../data/events.dart';
import '../data/grid_market.dart';
import '../data/premium_packages.dart';
import '../data/skins.dart';
import '../data/missions.dart';
import '../data/speedups.dart';
import '../data/story.dart';
import '../data/tower_catalog.dart';
import '../data/weather.dart';
import '../data/zones.dart';
import '../data/zone_theme.dart';
import '../models/enemy_type.dart';
import '../models/base_save.dart';
import '../models/grid_contract.dart';
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
import 'components/scenery.dart';
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

/// What the player is told when a night ends: the payout, the forecast, and
/// any story traffic that came in overnight.
class DawnReport {
  const DawnReport({
    required this.day,
    required this.missions,
    required this.forecast,
    required this.event,
    required this.bonus,
    required this.coins,
    required this.weather,
    required this.damaged,
    this.beat,
  });

  final int day;

  /// Today's objectives, listed so the morning card sets the day's agenda.
  final List<Mission> missions;

  /// What the Intel Center can see of the coming nights. Empty without one.
  final List<({int day, bool raided, double weight})> forecast;

  /// The week's world event.
  final WorldEvent event;

  final int bonus;
  final double coins;
  final Weather weather;

  /// How many structures came out of the night needing repair.
  final int damaged;

  /// Story traffic that arrived this morning, if any.
  final StoryBeat? beat;
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
    this.skins = const {},
    this.hasGridPass = false,
  });

  final LevelConfig config;
  final GameCallbacks callbacks;

  /// Combined premium perks the player owns, applied to this run.
  final PremiumPackage perks;

  /// A previously saved base to rebuild on load, if there is one. Survival is
  /// one continuous site, not a fresh run each time the app opens.
  final BaseSave? initialBase;

  /// Whether the season pass is active. It buys time and paint only: a longer
  /// offline window and the season wardrobe, never a number on the site.
  final bool hasGridPass;

  /// The cosmetic sets the player is wearing, keyed by [SkinSlot.name]. Pure
  /// paint: nothing here touches a stat.
  final Map<SkinSlot, Skin> skins;

  Skin skinFor(SkinSlot slot) =>
      skins[slot] ?? SkinCatalog.defaultFor(slot);

  /// This week's world event, resolved once at launch so it cannot change
  /// under the player mid-session.
  final WorldEvent worldEvent = EventCalendar.current(DateTime.now());

  /// Which zone this site sits in. Relocating to a harsher zone is the long
  /// game's reset: buildings are left behind, WATT and perks come with you.
  int zoneIndex = 0;
  SiteZone get zone => ZoneCatalog.at(zoneIndex);

  /// Days you must hold a site before the next zone will have you.
  bool get canRelocate =>
      ZoneCatalog.hasNextAfter(zoneIndex) &&
      dayNumber >= (ZoneCatalog.nextAfter(zoneIndex)?.unlockDay ?? 9999);

  /// Bulldozes the site and starts over in the same zone.
  ///
  /// Deleting the save alone is not enough: the live game keeps autosaving, so
  /// within seconds it writes the old site straight back. The running state has
  /// to be cleared too, which is what this does.
  void abandonSite() {
    _clearSite();
    zoneIndex = 0;
    dayNumber = 1;
    raidCount = 0;
    score = 0;
    storyDayShown = 0;
    blackoutCount = 0;
    timeOfDay = 0.28;
    _wasNight = false;
    weather = WeatherCatalog.forDay(1);
    money = (config.startMoney + perks.startMoneyBonus).toDouble();
    energy = 0;
    coreIntegrity = integrityMax;
    workloadIndex = 0;
    _threatRamp = DcWorkloadCatalog.workloads.first.threat;
    abilityActive.clear();
    abilityCooldown.clear();
    _rollMissions();
    _publishSnapshot(force: true);
  }

  /// Removes everything standing and everything in flight.
  void _clearSite() {
    for (final s in List<StructureComponent>.from(structures)) {
      _occupied.remove(s.coord);
      s.removeFromParent();
    }
    pvPanels.clear();
    windTurbines.clear();
    bessUnits.clear();
    dataCenters.clear();
    droneBays.clear();
    intelCenters.clear();
    _slowTowers.clear();
    for (final e in List<EnemyComponent>.from(enemies)) {
      e.removeFromParent();
    }
    enemies.clear();
    _pendingSpawns.clear();
    _nightWaveTimes.clear();
    gridContracts.clear();
  }

  /// Sells up and starts again in the next zone. Structures are left behind;
  /// WATT, premium perks and your record come with you, and the new site opens
  /// with capital scaled to how far you have come.
  void relocate() {
    if (!canRelocate) return;
    _clearSite();

    zoneIndex++;
    dayNumber = 1;
    raidCount = 0;
    timeOfDay = 0.28;
    _wasNight = false;
    weather = WeatherCatalog.forDay(1);
    // Seed capital scales with how far in you are, so a new zone is a fresh
    // start rather than starting over from nothing.
    money = (config.startMoney + perks.startMoneyBonus) * (1 + zoneIndex * 1.6);
    energy = 0;
    coreIntegrity = integrityMax;
    workloadIndex = 0;
    _threatRamp = DcWorkloadCatalog.workloads.first.threat;
    _rollMissions();
    _publishSnapshot(force: true);
  }

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

  /// How much of the Data Centers' demand the grid is actually meeting, 0..1.
  /// Everything they produce — money and WATT alike — scales with it.
  double dcLoadFraction = 0;

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
  final List<FacilityComponent> intelCenters = [];
  final Map<TileCoord, PositionComponent> _occupied = {};
  final Map<TileCoord, TowerComponent> _slowTowers = {};

  /// Total battery capacity: a small base plus every placed BESS unit.
  double get energyCapacity =>
      config.bessCapacity +
      perks.capacityBonus +
      bessUnits.fold(0.0, (s, u) => s + u.currentTier.capacity);

  /// Compute the Intel Centers borrow from the Data Centers. Intelligence work
  /// has to run somewhere, so knowing the future costs you earning capacity.
  double get intelDcLoad =>
      intelCenters.fold(0.0, (s, u) => s + u.currentTier.dcLoad);

  /// MONEY per second spent keeping the Intel Centers staffed and online.
  double get intelUpkeep =>
      intelCenters.fold(0.0, (s, u) => s + u.currentTier.upkeep);

  /// Net MONEY per second, everything included: what the machines are actually
  /// earning at their current load, minus upkeep, intel and any running
  /// contracts. This is the number that tells a player whether the site is
  /// solvent, which an integer balance ticking over once every few seconds
  /// cannot.
  double get netMoneyRate {
    var rate = dcIncome * dcLoadFraction - operatingCost - intelUpkeep;
    for (final c in gridContracts) {
      final v = c.price * c.ratePerSecond;
      rate += c.side == GridContractSide.buy ? -v : v;
    }
    return rate;
  }

  /// MONEY per second spent keeping everything on site running. Charged
  /// against the replacement value of what is built, so an upgraded site is
  /// genuinely more expensive to own.
  double get operatingCost {
    var total = 0.0;
    for (final s in structures) {
      total += s.currentTier.cost * upkeepRate;
      // A knocked-out building still costs money; it just earns nothing.
    }
    return total;
  }

  /// Fraction of a structure's build cost billed every second.
  ///
  /// Tuned so a site's running bill is a real drag on income rather than a
  /// rounding error: a plant worth 10,000 costs 40/s to own, which a single
  /// mid-tier contract barely covers.
  static const double upkeepRate = 0.004;

  /// Energy per second the Intel Centers draw just to stay awake.
  static const double intelEnergyPerCenter = 1.6;

  /// Combined Data-Center power actually available to earn with, after the
  /// Intel Centers have taken their share.
  double get dcTotalPower => (dataCenters.fold(
              0.0, (s, u) => s + u.currentTier.dcPower) -
          intelDcLoad)
      .clamp(0.0, double.infinity);

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

  /// Today's weather, rolled at each dawn. Swings solar, wind and raider speed.
  Weather weather = WeatherCatalog.clear;

  /// Actual PV output right now (nameplate scaled by sunlight and weather).
  double get effectivePvOutput =>
      pvOutput *
      sunFactor *
      weather.sunScale *
      zone.sunScale *
      worldEvent.sunScale;

  /// Combined nameplate output of all wind turbines (before wind).
  double get windOutput =>
      windTurbines.fold(0.0, (s, w) => s + w.currentTier.mwPerSecond);

  /// Wind strength in [0.15,1.0], oscillating over time. Works day AND night —
  /// wind is what carries the grid when the sun is down.
  double windFactor = 0.6;
  double _windPhase = 0;

  double get effectiveWindOutput =>
      windOutput *
      windFactor *
      weather.windScale *
      zone.windScale *
      worldEvent.windScale;

  /// Total energy generated right now: solar + wind, plus any always-on
  /// generator the player has unlocked.
  double get generation =>
      effectivePvOutput + effectiveWindOutput + perks.chargeRateBonus;

  /// The most recently chosen contract, used as the default for a newly built
  /// machine and as the site's headline job in the HUD. Each Data Center books
  /// its own work — see [setWorkloadFor].
  int workloadIndex = 0;
  DcWorkload get workload => DcWorkloadCatalog.workloads[workloadIndex];

  /// The contract a specific Data Center is running.
  DcWorkload workloadOf(FacilityComponent dc) =>
      DcWorkloadCatalog.workloads[
          dc.workloadIndex.clamp(0, DcWorkloadCatalog.workloads.length - 1)];

  /// How many Data Centers a site may run. A hard cap keeps the answer to
  /// every problem from being "build another one" and makes the choice of what
  /// each machine runs the actual decision.
  static const int maxDataCenters = 5;

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

  /// Books a contract on one Data Center, if the site's defences clear its
  /// security floor — you can't store bank records unguarded.
  void setWorkloadFor(FacilityComponent dc, int index) {
    final i = index.clamp(0, DcWorkloadCatalog.workloads.length - 1);
    if (securityRating < DcWorkloadCatalog.workloads[i].requiredSecurity) return;
    dc.workloadIndex = i;
    workloadIndex = i;
    _publishSnapshot(force: true);
  }

  /// Books the same contract on every machine. Kept for the site-wide control.
  void setWorkload(int index) {
    final i = index.clamp(0, DcWorkloadCatalog.workloads.length - 1);
    if (securityRating < DcWorkloadCatalog.workloads[i].requiredSecurity) return;
    workloadIndex = i;
    for (final dc in dataCenters) {
      dc.workloadIndex = i;
    }
    _publishSnapshot(force: true);
  }

  /// The share of a machine's compute left after the Intel Centers take theirs.
  double _dcShare(FacilityComponent dc) {
    final total =
        dataCenters.fold(0.0, (s, u) => s + u.currentTier.dcPower);
    if (total <= 0) return 0;
    return dc.currentTier.dcPower * (dcTotalPower / total);
  }

  /// Total Data Center energy draw per second, summed per machine because each
  /// runs its own contract.
  double get dcDraw => dataCenters.fold(
      0.0, (s, dc) => s + workloadOf(dc).draw * _dcShare(dc));

  /// Total money earned per second while powered. Mining contributes nothing
  /// here by design — it pays in WATT instead.
  double get dcIncome => dataCenters.fold(
        0.0,
        (s, dc) =>
            s +
                workloadOf(dc).income *
                    _dcShare(dc) *
                    perks.incomeMultiplier *
                    zone.incomeScale *
                    worldEvent.incomeScale,
      );

  /// Heat actually being applied right now. Switching to a hotter contract
  /// doesn't summon a maximum raid on the spot — word gets out over about a
  /// minute, which is the window the player uses to build defences before the
  /// new attention arrives.
  double _threatRamp = DcWorkloadCatalog.workloads.first.threat;

  /// How fast heat catches up with the current contract, per second.
  static const double threatRampRate = 0.025;

  /// How hot the base runs — scales raid frequency and size.
  double get threatMultiplier => _threatRamp * growthThreat;

  /// The hottest contract on site sets the attention the whole site gets: one
  /// machine full of government traffic is enough to bring people down on you.
  double get siteThreat {
    var hottest = DcWorkloadCatalog.workloads.first.threat;
    for (final dc in dataCenters) {
      final t = workloadOf(dc).threat;
      if (t > hottest) hottest = t;
    }
    return hottest;
  }

  /// Where heat is heading, so the HUD can warn before it lands.
  double get targetThreatMultiplier =>
      siteThreat * growthThreat * zone.threatScale * worldEvent.threatScale;

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

    _scatterScenery();

    core = CoreComponent(
      tile: Vector2(baseCoord.col.toDouble(), baseCoord.row.toDouble()),
      accent: theme.accent,
    );
    worldRoot.add(core);
  }

  /// Dresses the yard with ponds, trees, rocks and bushes so the map reads as a
  /// piece of countryside rather than a green sheet. All of it is cosmetic: a
  /// prop hides itself the moment something is built on its tile, so nothing
  /// here takes buildable ground away from the player. The layout is derived
  /// from a fixed seed, so a site looks the same every time it is loaded.
  void _scatterScenery() {
    final rng = math.Random(config.id * 7919 + 13);
    final pond = _pondTiles;

    // One or two ponds, grown as blobs from a seed tile well clear of the base.
    final pondCount = 1 + rng.nextInt(2);
    for (var p = 0; p < pondCount; p++) {
      final cx = 1 + rng.nextInt(config.gridCols - 2);
      final cy = 1 + rng.nextInt(config.gridRows - 2);
      if ((cx - baseCoord.col).abs() + (cy - baseCoord.row).abs() < 4) continue;
      final size = 3 + rng.nextInt(4);
      var x = cx, y = cy;
      for (var i = 0; i < size; i++) {
        final c = TileCoord(x, y);
        if (x > 0 &&
            y > 0 &&
            x < config.gridCols - 1 &&
            y < config.gridRows - 1 &&
            c != baseCoord) {
          pond.add(c);
        }
        // Random walk keeps the shape organic instead of a square block.
        if (rng.nextBool()) {
          x += rng.nextBool() ? 1 : -1;
        } else {
          y += rng.nextBool() ? 1 : -1;
        }
      }
    }

    for (final c in pond) {
      final touchesLand = [
            TileCoord(c.col + 1, c.row),
            TileCoord(c.col - 1, c.row),
            TileCoord(c.col, c.row + 1),
            TileCoord(c.col, c.row - 1),
          ].any((n) => !pond.contains(n));
      worldRoot.add(PondTile(
        tile: Vector2(c.col.toDouble(), c.row.toDouble()),
        seed: rng.nextDouble(),
        edges: touchesLand,
      ));
    }

    final centre =
        Vector2(config.gridCols / 2 - 0.5, config.gridRows / 2 - 0.5);
    for (var r = 0; r < config.gridRows; r++) {
      for (var c = 0; c < config.gridCols; c++) {
        final coord = TileCoord(c, r);
        if (coord == baseCoord) continue;

        final here = Vector2(c.toDouble(), r.toDouble());
        final onWater = pond.contains(coord);
        final byWater = !onWater &&
            [
              TileCoord(c + 1, r),
              TileCoord(c - 1, r),
              TileCoord(c, r + 1),
              TileCoord(c, r - 1),
            ].any(pond.contains);

        if (onWater) continue;

        // Reeds line the shore; elsewhere, density grows toward the edges so
        // the middle of the yard stays open to build on.
        SceneryKind? kind;
        if (byWater && rng.nextDouble() < 0.55) {
          kind = SceneryKind.reeds;
        } else {
          final edgeness =
              ((here - centre).length / (config.gridCols / 2)).clamp(0.0, 1.0);
          final chance = 0.04 + edgeness * 0.30;
          if (rng.nextDouble() < chance) {
            final roll = rng.nextDouble();
            kind = roll < 0.34
                ? SceneryKind.tree
                : roll < 0.58
                    ? SceneryKind.pine
                    : roll < 0.82
                        ? SceneryKind.bush
                        : SceneryKind.rock;
          }
        }
        if (kind == null) continue;

        _sceneryTiles[coord] = kind;
        worldRoot.add(SceneryComponent(
          tile: here,
          kind: kind,
          seed: rng.nextDouble(),
        ));
      }
    }
  }

  /// Where the props and water are, so building on them can be charged for.
  final Map<TileCoord, SceneryKind> _sceneryTiles = {};
  final Set<TileCoord> _pondTiles = {};

  /// What it costs to make a tile buildable. Ground you have to clear or fill
  /// is worth less than open ground, so the free middle of the yard is real
  /// estate worth planning around rather than scenery being a free bonus.
  int clearingCostAt(TileCoord coord) {
    if (_pondTiles.contains(coord)) return 260; // drain and backfill
    switch (_sceneryTiles[coord]) {
      case SceneryKind.tree:
      case SceneryKind.pine:
        return 90; // fell it and pull the stump
      case SceneryKind.rock:
        return 140; // break it out
      case SceneryKind.bush:
      case SceneryKind.reeds:
        return 40;
      case null:
        return 0;
    }
  }

  /// True when something is built on this tile — scenery uses it to get out of
  /// the way of real structures.
  bool isOccupiedTile(int col, int row) =>
      _occupied.containsKey(TileCoord(col, row));

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
    _upgradesToday++;
    _checkMissions();
    _emitSfx(Sfx.towerPlace);
    _selectStructure(coord);
    _publishSnapshot(force: true);
  }

  // ---- Update loop ----

  @override
  void update(double dt) {
    super.update(dt);

    if (phase != RunPhase.won && phase != RunPhase.lost) {
      _tickAbilities(dt);
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
    final beforeCharge = energy;
    energy = (energy + generation * dt).clamp(0, energyCapacity);

    // 1b) With a utility interconnect, whatever the battery couldn't take is
    //     exported for cash instead of being thrown away — the reward for
    //     overbuilding generation.
    if (perks.gridExportRate > 0) {
      final wanted = generation * dt;
      final absorbed = energy - beforeCharge;
      final spilled = (wanted - absorbed).clamp(0.0, double.infinity);
      if (spilled > 0) {
        // Sold at the live market rate — surplus is worth most when the zone is
        // short, which is exactly when your battery would rather keep it.
        final paid = spilled * gridSellPrice * perks.gridExportRate;
        money += paid;
        gridExportEarned += paid;
      }
    }

    // 1c) Fixed-term contracts settle before spot buying, so a running buy
    //     contract keeps the battery off the spot market.
    _tickContracts(dt);

    // 1d) Buying off the grid at spot. Anyone can import; it just costs whatever the
    //     market is asking, which at dusk is brutal and at midday is nearly
    //     free. This is the other half of the same connection.
    if (gridImportEnabled && energyCapacity > 0) {
      final floor = energyCapacity * importThreshold;
      if (energy < floor) {
        final wanted = math.min(floor - energy, 25.0 * dt);
        final bill = wanted * gridPrice;
        if (money >= bill) {
          money -= bill;
          energy = (energy + wanted).clamp(0, energyCapacity);
          gridImportSpent += bill;
        }
      }
    }

    // 1e) Intel Centers run whether or not anything else does: they cost cash
    //     and power every second they are switched on. Let them brown out
    //     rather than bankrupt the site.
    if (intelCenters.isNotEmpty) {
      final bill = intelUpkeep * dt;
      final juice = intelEnergyPerCenter * intelCenters.length * dt;
      if (money >= bill && energy >= juice) {
        money -= bill;
        energy -= juice;
      }
    }

    // 1f) Operating costs. Everything standing on the site costs money to keep
    //     standing — staff, spares, insurance — billed against what it is worth.
    //     A site's running bill therefore grows as fast as the site does, which
    //     is what stops cash from piling up with nothing to buy.
    final opex = operatingCost * dt;
    if (opex > 0) {
      money = math.max(0.0, money - opex);
    }

    // 2) Data Centers consume to run, and pay out while powered — but they only
    //    get what's above the defence reserve, so a greedy workload can't starve
    //    the towers and leave the base defenceless.
    // Machines take what the grid can actually give them and earn in
    // proportion. All-or-nothing made a site sitting exactly on its reserve
    // flicker between running and stopped every frame — the HUD would read
    // NO POWER while money kept climbing on the frames that happened to
    // succeed. A brownout is a real state, so it is modelled as one.
    final want = dcHalted ? 0.0 : dcDraw * dt;
    final spare = math.max(0.0, energy - defenceReserve);
    if (dcHalted || dcTotalPower <= 0 || want <= 0) {
      dcLoadFraction = 0;
      dcPowered = false;
    } else {
      final served = math.min(want, spare);
      dcLoadFraction = (served / want).clamp(0.0, 1.0);
      energy -= served;
      money += dcIncome * dt * dcLoadFraction;
      dcPowered = dcLoadFraction > 0.98;
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
  /// The structure a raider in [pos] should hit next.
  ///
  /// Raiders are paid to cause damage that matters, so they go for the most
  /// valuable thing in reach rather than whatever happens to be closest: the
  /// Data Center running government traffic before the shed, the Intel Center
  /// before a bush of a barrier. Distance still counts — a juicy target across
  /// the yard loses to a good one underneath them.
  StructureComponent? nearestStructureTo(Vector2 pos, {double within = 2.5}) {
    StructureComponent? best;
    var bestScore = 0.0;
    for (final s in structures) {
      if (s.isDestroyed) continue;
      final d = (s.tile - pos).length;
      if (d > within) continue;
      final score = _targetValue(s) / (0.6 + d);
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }
    return best;
  }

  /// How badly a raider wants to wreck this. Built on what the thing costs to
  /// replace, then weighted by what it does for the site.
  double _targetValue(StructureComponent s) {
    var v = s.currentTier.cost.toDouble();
    switch (s.spec.category) {
      case TowerCategory.datacenter:
        // The earner, and the reason anyone is here. Hotter contract, bigger
        // prize.
        final w = s is FacilityComponent ? workloadOf(s) : workload;
        v *= 2.2 * w.threat;
        break;
      case TowerCategory.intel:
        // Blinding the site is worth a lot to whoever is paying for this.
        v *= 2.0;
        break;
      case TowerCategory.storage:
        v *= 1.4; // no battery, no defence
        break;
      case TowerCategory.damage:
      case TowerCategory.droneBay:
        v *= 1.2; // shooting back makes you a target
        break;
      case TowerCategory.economy:
      case TowerCategory.slow:
        break;
    }
    return v;
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
    _repairsToday++;
    _checkMissions();
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
      _repairsToday++;
    }
    _checkMissions();
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

  /// Cash earned by exporting surplus power, for the HUD to show off.
  double gridExportEarned = 0;

  /// Cash spent buying power off the grid.
  double gridImportSpent = 0;

  /// Whether the site tops its battery up from the public grid when it runs
  /// low, at whatever the spot price happens to be. Off by default: buying
  /// power is a choice with a bill attached.
  bool gridImportEnabled = false;

  /// Fixed-term contracts currently running.
  final List<GridContract> gridContracts = [];

  /// The imbalance charge multiplier: fail to deliver on a sell contract and
  /// the grid buys the missing power on your behalf, at a punitive rate. This
  /// is what stops a sell contract from being free money.
  static const double imbalancePenalty = 1.6;

  /// Signs a contract at the current spot price. Buy contracts carry the
  /// utility's markup; sell contracts pay under spot. Returns false if the
  /// site already has as many as it can manage.
  bool signContract(GridContractSide side, double rate, double seconds) {
    if (gridContracts.length >= 4) return false;
    final spot = gridPrice;
    final price =
        side == GridContractSide.buy ? spot * 1.06 : spot * GridMarket.sellFraction;
    gridContracts.add(GridContract(
      side: side,
      price: price,
      ratePerSecond: rate,
      totalSeconds: seconds,
    ));
    _publishSnapshot(force: true);
    return true;
  }

  /// Runs the active contracts for [dt]. Buy contracts deliver power and bill
  /// you; sell contracts take power off your battery and pay you, or charge
  /// imbalance for whatever you could not deliver.
  void _tickContracts(double dt) {
    if (gridContracts.isEmpty) return;
    final spot = gridPrice;
    for (final c in gridContracts) {
      final step = math.min(dt, c.secondsLeft);
      if (step <= 0) continue;
      final want = c.ratePerSecond * step;

      if (c.side == GridContractSide.buy) {
        final bill = want * c.price;
        if (money >= bill) {
          money -= bill;
          // Power over the battery's brim is simply lost — size your storage.
          energy = (energy + want).clamp(0, energyCapacity);
          c.energyMoved += want;
          c.settled -= bill;
        }
      } else {
        // Deliver from whatever sits above the defence reserve: a sell contract
        // must never be able to disarm the site.
        final available = (energy - defenceReserve).clamp(0.0, double.infinity);
        final delivered = math.min(want, available);
        energy -= delivered;
        final paid = delivered * c.price;
        money += paid;
        c.energyMoved += delivered;
        c.settled += paid;

        final missing = want - delivered;
        if (missing > 0) {
          final fine = missing * spot * imbalancePenalty;
          money -= fine;
          c.shortfall += missing;
          c.settled -= fine;
        }
      }
      c.secondsLeft -= step;
    }

    final finished = gridContracts.where((c) => c.isDone).toList();
    for (final c in finished) {
      spawnFloatingText(
        c.shortfall > 0
            ? 'Contract ended · shortfall'
            : 'Contract settled ${c.settled >= 0 ? '+' : ''}'
                '${c.settled.round()}M',
        Vector2(baseCoord.col.toDouble(), baseCoord.row.toDouble()),
        c.shortfall > 0 ? const Color(0xFFE23D4B) : const Color(0xFF2FBF71),
      );
    }
    gridContracts.removeWhere((c) => c.isDone);
  }

  /// Buy below this fraction of capacity — enough headroom that the towers
  /// never go quiet, without paying to fill a battery the sun would fill free.
  static const double importThreshold = 0.35;

  /// Live import price per unit of energy.
  double get gridPrice =>
      GridMarket.priceAt(
        timeOfDay: timeOfDay,
        sunFactor: sunFactor,
        weather: weather,
        day: dayNumber,
      ) *
      zone.priceScale *
      worldEvent.priceScale;

  /// Live export price per unit of energy.
  double get gridSellPrice => gridPrice * GridMarket.sellFraction;

  /// What one WATT fetches when sold for cash. WATT is deliberately scarce —
  /// only mining hardware mints it — so cashing out is a real decision: spend
  /// it on permanent perks, or burn it to get through a bad week.
  static const double wattToCash = 4000.0;

  /// Sells [amount] WATT for cash. Returns false when the balance is short.
  bool exchangeWatt(double amount) {
    if (amount <= 0 || coinsEarned < amount) return false;
    coinsEarned -= amount;
    money += amount * wattToCash;
    spawnFloatingText(
      '+${(amount * wattToCash).round()}M',
      Vector2(baseCoord.col.toDouble(), baseCoord.row.toDouble()),
      const Color(0xFF2FBF71),
    );
    _publishSnapshot(force: true);
    return true;
  }

  /// Coins per second while a crypto workload runs powered — scales with how
  /// much Data Center capacity is pointed at it.
  /// WATT minted per second.
  ///
  /// Deliberately glacial: one mining machine produces [wattPerHour] per real
  /// hour, and each upgrade tier on that machine adds 15%. WATT is meant to be
  /// a store of value that takes real time to accumulate, not a second cash
  /// meter — everything priced in it is priced against hours, not minutes.
  ///
  /// Emission is written as a single multiplier so a halving schedule can be
  /// dropped in later without touching anything that spends WATT.
  static const double wattPerHour = 0.01;
  static const double tierMiningStep = 0.15;

  /// Current emission multiplier. Reserved for the halving: drop this to 0.5,
  /// then 0.25, as the total minted supply passes each threshold.
  double get emissionMultiplier => 1.0;

  double get coinRate {
    if (dcLoadFraction <= 0) return 0;
    var perHour = 0.0;
    for (final dc in dataCenters) {
      if (!workloadOf(dc).minesCoins) continue;
      // Each tier makes that specific machine 15% more productive.
      perHour += wattPerHour * math.pow(1 + tierMiningStep, dc.tier);
    }
    return perHour *
        dcLoadFraction /
        3600.0 *
        (1 + perks.miningBonus) *
        emissionMultiplier *
        worldEvent.miningScale;
  }

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
  /// Attention grows with what the site is worth, but on a curve rather than a
  /// line, and it never stops: a site fifty times richer is not fifty times
  /// more watched, yet it is never left alone either.
  ///
  /// The scale is tied to build costs — when those tripled, a starter site was
  /// pinning the old ceiling on day one — and the reference point is roughly
  /// what a modest working site is worth.
  static const double threatReferenceValue = 6000.0;

  double get growthThreat =>
      1.0 + 0.55 * math.log(1 + baseValue / threatReferenceValue);

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
    if (spec.category == TowerCategory.datacenter &&
        dataCenters.length >= maxDataCenters) {
      spawnFloatingText(
        'DC limit ($maxDataCenters)',
        Vector2(coord.col.toDouble(), coord.row.toDouble()),
        const Color(0xFFE23D4B),
      );
      return;
    }

    // Clearing the ground is part of the build cost, charged in one go.
    final clearing = clearingCostAt(coord);
    if (!_spendMoney(spec.tier(0).cost + clearing)) return;
    if (clearing > 0) {
      _sceneryTiles.remove(coord);
      _pondTiles.remove(coord);
      spawnFloatingText(
        '-${clearing}M clearing',
        Vector2(coord.col.toDouble(), coord.row.toDouble()),
        const Color(0xFFE0A050),
      );
    }

    final comp = _createStructure(spec, coord, 0);
    worldRoot.add(comp);
    _occupied[coord] = comp;
    _buildsToday++;
    _checkMissions();
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
        d.workloadIndex = workloadIndex;
        d.dcIndex = dataCenters.length;
        dataCenters.add(d);
        comp = d;
        break;
      case TowerCategory.intel:
        final intel = FacilityComponent(
            spec: spec,
            coord: coord,
            tier: tier,
            spriteKey: 'intel',
            widthTiles: 1.7);
        intelCenters.add(intel);
        comp = intel;
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
    _killsToday++;
    _checkMissions();
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
    _blackoutTonight = true;
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
    weather = WeatherCatalog.forDay(dayNumber);
    _blackoutTonight = false;
    _rollMissions();
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
      // Bad weather grounds raiders as surely as it dims the panels.
      speed: spec.baseSpeed * speedScale * weather.raiderSpeedScale,
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
      zoneIndex: zoneIndex,
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
      final comp = _createStructure(spec, coord, st.tier.clamp(0, spec.maxTier));
      worldRoot.add(comp);
      _occupied[coord] = comp;
      if (comp is StructureComponent) {
        comp.restoreHealthFraction(st.healthFraction);
      }
    }

    zoneIndex = save.zoneIndex;
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
    weather = WeatherCatalog.forDay(dayNumber);
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

    final passHours = hasGridPass ? 8 : 0;
    final maxOfflineSeconds =
        (8 + perks.offlineHoursBonus + passHours) * 3600.0;
    const offlineRate = 0.35; // unattended sites run at a third of full pace
    final seconds = math.min(away, maxOfflineSeconds);

    // Generation has to cover the draw for the DC to have been running at all.
    final couldRun = dcTotalPower > 0 &&
        (pvOutput * 0.5 + windOutput * 0.6) >= dcDraw * 0.8;
    if (!couldRun) {
      return OfflineReport(seconds: seconds, money: 0, coins: 0);
    }

    // An unattended site fills its holding tanks and then spills. Storage is
    // the cap, so the player who wants longer unattended runs has to build
    // batteries for it — and there is always a point past which staying away
    // is pure waste.
    final produced = dcIncome * seconds * offlineRate;
    final vault = offlineVaultCapacity;
    final banked = math.min(produced, vault);
    final wasted = produced - banked;

    return OfflineReport(
      seconds: seconds,
      money: banked.round(),
      coins: coinRate * seconds * offlineRate,
      wasted: wasted.round(),
      vaultCapacity: vault.round(),
      hoursToFill: dcIncome * offlineRate <= 0
          ? 0
          : vault / (dcIncome * offlineRate) / 3600.0,
    );
  }

  /// Applies a purchased speed-up. Everything it grants is something the site
  /// would have produced on its own given time — the purchase buys the time,
  /// not an advantage that is otherwise unreachable.
  void applySpeedup(Speedup item) {
    switch (item.effect) {
      case SpeedupEffect.bankedHours:
        final seconds = item.amount * 3600;
        money += dcIncome * seconds * 0.35;
        coinsEarned += coinRate * seconds * 0.35;
        break;
      case SpeedupEffect.cash:
        money += item.amount;
        break;
      case SpeedupEffect.gridPass:
        // The pass itself is a standing entitlement held in the profile; the
        // in-run half is the first day's shift, credited on purchase.
        money += dcIncome * 4 * 3600 * 0.35;
        break;
      case SpeedupEffect.fullRepair:
        for (final s in structures) {
          s.repairFully();
        }
        break;
    }
    _publishSnapshot(force: true);
  }

  /// How much unattended production the site can hold before it spills.
  /// Scales with storage, so batteries buy time away as well as security.
  double get offlineVaultCapacity => 900 + energyCapacity * 22;

  /// Credits cash from outside the simulation (streak rewards and the like).
  void grantCash(double amount) {
    money += amount;
    _publishSnapshot(force: true);
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

  // ---- Manual abilities ----

  /// Seconds left on each active effect, and on each cooldown.
  final Map<AbilityKind, double> abilityActive = {};
  final Map<AbilityKind, double> abilityCooldown = {};

  bool isAbilityActive(AbilityKind k) => (abilityActive[k] ?? 0) > 0;
  double cooldownLeft(AbilityKind k) => abilityCooldown[k] ?? 0;
  bool canUseAbility(AbilityKind k) =>
      cooldownLeft(k) <= 0 && !isAbilityActive(k);

  /// Damage multiplier on towers while Overcharge runs.
  double get overchargeFactor => isAbilityActive(AbilityKind.overcharge) ? 2.0 : 1.0;

  /// True while the Data Centers are deliberately stopped.
  bool get dcHalted => isAbilityActive(AbilityKind.shutdown);

  /// True while the site is dark and raiders cannot find anything.
  bool get siteDark => isAbilityActive(AbilityKind.blackout);

  /// Fires an ability if it is off cooldown. Returns false when it isn't.
  bool useAbility(AbilityKind kind) {
    if (!canUseAbility(kind)) return false;
    final a = AbilityCatalog.of(kind);

    if (kind == AbilityKind.crew) {
      // Instant: costs energy proportional to the damage being undone, so a
      // wrecked site can't patch itself for free mid-raid.
      final damaged = structures.where((s) => s.needsRepair).toList();
      if (damaged.isEmpty) return false;
      final cost = 6.0 * damaged.length;
      if (!tryDrawEnergy(cost)) return false;
      for (final s in damaged) {
        s.restoreHealthFraction(
            (s.healthFraction + 0.30).clamp(0.0, 1.0));
      }
      spawnFloatingText(
        'Crew patch ×${damaged.length}',
        Vector2(baseCoord.col.toDouble(), baseCoord.row.toDouble()),
        const Color(0xFF2FBF71),
      );
    } else {
      abilityActive[kind] = a.duration;
      spawnFloatingText(
        '${a.emoji} ${a.name}',
        Vector2(baseCoord.col.toDouble(), baseCoord.row.toDouble()),
        const Color(0xFF2E7DF6),
      );
    }

    abilityCooldown[kind] = a.cooldown;
    addShake(shakeMagnitudeLight);
    _publishSnapshot(force: true);
    return true;
  }

  void _tickAbilities(double dt) {
    for (final k in AbilityKind.values) {
      final active = abilityActive[k] ?? 0;
      if (active > 0) {
        abilityActive[k] = (active - dt).clamp(0.0, double.infinity);
      }
      final cd = abilityCooldown[k] ?? 0;
      if (cd > 0) {
        abilityCooldown[k] = (cd - dt).clamp(0.0, double.infinity);
      }
    }
  }

  // ---- Daily missions ----
  // Small goals that reset every dawn and pay WATT, so a short session still
  // ends with something banked.

  List<Mission> missions = MissionCatalog.forDay(1);

  /// Progress per mission index, and which have already paid out.
  List<int> missionProgress = [0, 0, 0];
  List<bool> missionDone = [false, false, false];

  int _killsToday = 0;
  int _buildsToday = 0;
  int _upgradesToday = 0;
  int _repairsToday = 0;
  bool _blackoutTonight = false;

  int missionValue(MissionMetric m) {
    switch (m) {
      case MissionMetric.kills:
        return _killsToday;
      case MissionMetric.builds:
        return _buildsToday;
      case MissionMetric.upgrades:
        return _upgradesToday;
      case MissionMetric.repairs:
        return _repairsToday;
      case MissionMetric.nightsHeld:
        // Credited at dawn, and only if the night went clean.
        return 0;
    }
  }

  /// Re-reads the counters and pays out anything newly finished. Cheap enough
  /// to call whenever one of those counters moves.
  void _checkMissions() {
    for (var i = 0; i < missions.length; i++) {
      if (missionDone[i]) continue;
      final m = missions[i];
      if (m.metric == MissionMetric.nightsHeld) continue;
      missionProgress[i] = missionValue(m.metric);
      if (missionProgress[i] >= m.target) {
        missionDone[i] = true;
        coinsEarned += m.reward;
        spawnFloatingText(
            '+${m.reward.toStringAsFixed(1)} WTT',
            Vector2(baseCoord.col.toDouble(), baseCoord.row.toDouble()),
            const Color(0xFFF4B740));
      }
    }
  }

  /// Rolls a fresh set of missions and clears the day's counters.
  void _rollMissions() {
    missions = MissionCatalog.forDay(dayNumber);
    missionProgress = List<int>.filled(missions.length, 0);
    missionDone = List<bool>.filled(missions.length, false);
    _killsToday = 0;
    _buildsToday = 0;
    _upgradesToday = 0;
    _repairsToday = 0;
  }

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
    final target = siteThreat;
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

  /// Whether night [day] gets raided at all, and how heavy it is.
  ///
  /// Not every night is a raid: quiet nights are what make an Intel Center
  /// worth its price, because knowing which nights are safe is the difference
  /// between building and cowering. Derived from the day number and the site's
  /// heat, so it is knowable in advance — that is the whole point.
  ({bool raided, double weight}) raidForecastFor(int day) {
    if (day <= 1) return (raided: false, weight: 0);
    final r = math.Random(day * 4231 + 907);
    final roll = r.nextDouble();
    // A hot site is watched constantly; a quiet one is mostly left alone.
    final chance = (0.35 + 0.30 * threatMultiplier).clamp(0.35, 0.92);
    if (roll > chance) return (raided: false, weight: 0);
    // Weight decides how many waves the night carries.
    final weight = 0.6 + r.nextDouble() * 0.9;
    return (raided: true, weight: weight);
  }

  /// How many nights ahead the site can see, from its best Intel Center.
  int get forecastRange {
    var best = 0;
    for (final c in intelCenters) {
      if (c.isOffline) continue; // a wrecked centre reports nothing
      final n = c.currentTier.forecastNights;
      if (n > best) best = n;
    }
    return best;
  }

  /// How often the readout is right, from the best working centre. Zero when
  /// the site has no intelligence at all.
  double get forecastAccuracy {
    var best = 0.0;
    for (final c in intelCenters) {
      if (c.isOffline) continue;
      final a = c.currentTier.forecastAccuracy;
      if (a > best) best = a;
    }
    return best;
  }

  /// What the centre *reports* about night [day], which is not always what
  /// happens. A wrong reading is a confident wrong reading — it names the
  /// opposite of the truth — because a forecast that hedged would be useless
  /// and would never actually cost the player anything.
  ({bool raided, double weight}) reportedForecastFor(int day) {
    final truth = raidForecastFor(day);
    final acc = forecastAccuracy;
    if (acc <= 0) return truth;
    // Deterministic per night *and* per accuracy level, so a reading never
    // flickers between frames, and upgrading the centre re-reads the night.
    final r = math.Random(day * 3319 + (acc * 100).round() * 17);
    if (r.nextDouble() < acc) return truth;
    return truth.raided
        ? (raided: false, weight: 0)
        : (raided: true, weight: 0.6 + r.nextDouble() * 0.9);
  }

  /// The forecast the player is allowed to see: one entry per night within
  /// [forecastRange], starting with tonight.
  List<({int day, bool raided, double weight})> get visibleForecast {
    final out = <({int day, bool raided, double weight})>[];
    for (var i = 0; i < forecastRange; i++) {
      final d = dayNumber + i;
      final f = reportedForecastFor(d);
      out.add((day: d, raided: f.raided, weight: f.weight));
    }
    return out;
  }

  /// Dusk: schedule tonight's waves. Heat decides how many come, spread across
  /// the dark hours so there's always a lull to repair in.
  void _onNightfall() {
    _nightClock = 0;
    _nightWaveTimes.clear();

    // A full night is now twelve real minutes, so a single wave would leave it
    // mostly empty. Heat still decides how heavy the night is; the night's
    // length decides how many pieces that comes in.
    final forecast = raidForecastFor(dayNumber);
    if (!forecast.raided) {
      // A quiet night. Nothing comes; the site gets a full dark shift to build.
      nightWavesTotal = 0;
      nightWavesDone = 0;
      _publishSnapshot(force: true);
      return;
    }

    final waves =
        (2 + threatMultiplier * 1.8 * forecast.weight).round().clamp(1, 9);
    // Night is half the cycle; leave the last stretch clear so a night always
    // ends with a breather rather than a spawn.
    final nightSeconds = config.dayLength * 0.5;
    final window = nightSeconds * 0.78;
    for (var i = 0; i < waves; i++) {
      _nightWaveTimes.add(waves == 1 ? 2.0 : 2.0 + window * (i / (waves - 1)));
    }
    nightWavesTotal = waves;
    nightWavesDone = 0;
    _publishSnapshot(force: true);
  }

  /// The morning's news, handed to the UI once per dawn.
  DawnReport? pendingDawn;

  /// Dawn: the night is survived. Pay for it, and roll the day over.
  void _onDawn() {
    _nightWaveTimes.clear();
    dayNumber++;
    weather = WeatherCatalog.forDay(dayNumber);
    // A survival payout that grows with the day and the contract, so pushing
    // into hotter work is worth the risk beyond the per-second income.
    lastDawnBonus =
        (25 + dayNumber * 12 * workload.threat).round();
    money += lastDawnBonus;
    final mining = dataCenters.any((dc) => workloadOf(dc).minesCoins);
    // A night's mining, on the same scale as everything else WATT.
    final coinBonus = mining ? coinRate * config.dayLength * 0.5 : 0.0;
    coinsEarned += coinBonus;

    // The night-hold mission pays only if the grid never went dark.
    for (var i = 0; i < missions.length; i++) {
      if (missionDone[i]) continue;
      if (missions[i].metric != MissionMetric.nightsHeld) continue;
      if (_blackoutTonight) continue;
      missionDone[i] = true;
      missionProgress[i] = 1;
      money += missions[i].reward;
    }
    _blackoutTonight = false;
    _rollMissions();

    final beat = dayNumber > storyDayShown ? StoryCatalog.forDay(dayNumber) : null;
    if (beat != null) storyDayShown = dayNumber;

    pendingDawn = DawnReport(
      day: dayNumber,
      missions: missions,
      forecast: visibleForecast,
      event: worldEvent,
      bonus: lastDawnBonus,
      coins: coinBonus,
      weather: weather,
      damaged: damagedCount,
      beat: beat,
    );
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
      dcLoadFraction: dcLoadFraction,
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
      forecastRange: forecastRange,
      tonightRaided:
          forecastRange > 0 && reportedForecastFor(dayNumber).raided,
      tonightWeight:
          forecastRange > 0 ? reportedForecastFor(dayNumber).weight : 0.0,
      forecastAccuracy: forecastAccuracy,
      gridPrice: gridPrice,
      gridImporting: gridImportEnabled,
      gridContracts: gridContracts.length,
      operatingCost: operatingCost,
      netMoneyRate: netMoneyRate,
      zoneName: zone.name,
      zoneEmoji: zone.emoji,
      eventName: worldEvent.name,
      eventEmoji: worldEvent.emoji,
      canRelocate: canRelocate,
      weatherEmoji: weather.emoji,
      weatherName: weather.name,
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
