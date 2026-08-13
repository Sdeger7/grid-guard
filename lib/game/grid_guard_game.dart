import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../data/abilities.dart';
import '../data/cities.dart';
import '../data/dc_workload.dart';
import '../data/enemy_catalog.dart';
import '../data/events.dart';
import '../data/grid_market.dart';
import '../data/premium_packages.dart';
import '../data/skins.dart';
import '../data/solar.dart';
import '../data/missions.dart';
import '../data/speedups.dart';
import '../data/story.dart';
import '../data/tower_catalog.dart';
import '../data/weather.dart';
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

  /// Retained so older saves still load; the site's character now comes from
  /// its province rather than an invented zone.
  int zoneIndex = 0;

  /// Days you must hold a site before the next zone will have you.
  /// Moving is a purchase, not a milestone: any province is open at any time
  /// if you can pay for the plot and the haulage.
  int relocationCostTo(City target) =>
      CityCatalog.relocationCost(city, target);

  bool canRelocateTo(City target) =>
      target.id != cityId && money >= relocationCostTo(target);

  /// Moves the operation to another province. The buildings do not come — the
  /// cost is the new plot plus hauling what can be salvaged, and the salvage is
  /// what pays for the first structures on the new ground.
  bool relocateTo(City target) {
    if (!canRelocateTo(target)) return false;
    final bill = relocationCostTo(target);
    // Half the value of what you leave behind is recovered as salvage.
    final salvage = baseValue * 0.5;
    _clearSite();
    money = math.max(0, money - bill) + salvage;
    cityId = target.id;
    dayNumber = 1;
    raidCount = 0;
    energy = 0;
    coreIntegrity = integrityMax;
    workloadIndex = 0;
    _threatRamp = DcWorkloadCatalog.workloads.first.threat;
    _rollMissions();
    _publishSnapshot(force: true);
    return true;
  }

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
      cityId: cityId,
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
    cityId = save.cityId;
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

  /// Two-digit clock text for a time, for the HUD.
  static String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

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
      zoneName: city.name,
      zoneEmoji: '📍',
      sunriseLabel: _clock(sun.sunrise),
      sunsetLabel: _clock(sun.sunset),
      eventName: worldEvent.name,
      eventEmoji: worldEvent.emoji,
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
