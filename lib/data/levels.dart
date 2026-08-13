import '../models/enemy_type.dart';
import '../models/level_config.dart';

/// Builds the full 30-level campaign (5 zones x 6 levels) procedurally from a
/// difficulty curve, then exposes it as an immutable list.
///
/// Curve (matches the design doc): each level adds either a wave or an enemy
/// variant; each zone raises health/speed scaling; every 6th level is an
/// **Overload Boss Wave** — a dense, synchronized, multi-type finale.
class LevelCatalog {
  static final List<LevelConfig> levels = _build();

  static LevelConfig byId(int id) =>
      levels.firstWhere((l) => l.id == id);

  static LevelConfig byZoneIndex(int zone, int indexInZone) =>
      levels.firstWhere((l) => l.zone == zone && l.indexInZone == indexInZone);

  static const int gridCols = 9;
  static const int gridRows = 9;

  /// The single endless "base survival" map: an open yard with the base at the
  /// centre, free building anywhere, and raids flying in from all four edges.
  static final LevelConfig survival = LevelConfig(
    id: 1000,
    zone: 1,
    indexInZone: 1,
    gridCols: 11,
    gridRows: 11,
    path: _pathTemplate(1), // unused in endless (air raids), kept for the model
    safeZones: const {},
    waves: const [],
    startingMw: 0,
    coreIntegrity: 160,
    lowDamageStarThreshold: 1,
    timeStarThreshold: 999999,
    startMoney: 170,
    startEnergy: 60,
    bessCapacity: 90,
    dayLength: 240,
    startTimeOfDay: 0.33,
    endless: true,
  );

  /// The enemy route in tile space. Zone 1 is a hand-authored serpentine with
  /// two long horizontal "kill lanes"; other zones fall back to parity-based
  /// S-templates for now. All segments stay axis-aligned for barrier placement.
  static List<TileCoord> _pathTemplate(int zone) {
    if (zone == 1) {
      // Enters top-left, snakes down through two straight lanes to the core at
      // (8,7). The row-3 and row-5 straights are the designed kill zones.
      return const [
        TileCoord(0, 1),
        TileCoord(6, 1),
        TileCoord(6, 3),
        TileCoord(2, 3),
        TileCoord(2, 5),
        TileCoord(6, 5),
        TileCoord(6, 7),
        TileCoord(8, 7),
      ];
    }
    if (zone.isOdd) {
      return const [
        TileCoord(0, 1),
        TileCoord(7, 1),
        TileCoord(7, 4),
        TileCoord(1, 4),
        TileCoord(1, 7),
        TileCoord(8, 7),
      ];
    }
    return const [
      TileCoord(0, 7),
      TileCoord(6, 7),
      TileCoord(6, 4),
      TileCoord(2, 4),
      TileCoord(2, 1),
      TileCoord(8, 1),
    ];
  }

  /// Buildable pads (PV panel / Shock Transformer sites). Placement is a design
  /// choice, not a scatter: Zone 1 clusters strong pads around the central kill
  /// zone, with a couple of far, low-coverage "greedy economy" corners.
  /// The Set can't be `const` (TileCoord overrides ==/hashCode) but its elements
  /// are compile-time constants.
  static Set<TileCoord> _safeZones(int zone) {
    if (zone == 1) {
      return {
        // Central kill zone — flanks the row-3 lane above and below. Towers
        // here get the most coverage; this is the obvious strong play.
        const TileCoord(3, 2),
        const TileCoord(4, 2),
        const TileCoord(5, 2),
        const TileCoord(3, 4),
        const TileCoord(4, 4),
        const TileCoord(5, 4),
        // Secondary — covers the lower row-5 lane.
        const TileCoord(3, 6),
        const TileCoord(5, 6),
        // Last-line pad near the core.
        const TileCoord(7, 6),
        // Far, low-coverage corner: good for a greedy early PV, weak for defence.
        const TileCoord(1, 3),
      };
    }
    if (zone.isOdd) {
      return {
        const TileCoord(2, 2),
        const TileCoord(4, 2),
        const TileCoord(6, 2),
        const TileCoord(3, 5),
        const TileCoord(5, 5),
        const TileCoord(7, 5),
        const TileCoord(3, 6),
        const TileCoord(5, 6),
      };
    }
    return {
      const TileCoord(2, 6),
      const TileCoord(4, 6),
      const TileCoord(6, 6),
      const TileCoord(3, 2),
      const TileCoord(5, 2),
      const TileCoord(7, 2),
      const TileCoord(3, 3),
      const TileCoord(5, 3),
    };
  }

  static List<LevelConfig> _build() {
    final out = <LevelConfig>[];
    var id = 1;
    for (var zone = 1; zone <= 5; zone++) {
      for (var idx = 1; idx <= 6; idx++) {
        out.add(_buildLevel(id, zone, idx));
        id++;
      }
    }
    return out;
  }

  static LevelConfig _buildLevel(int id, int zone, int idx) {
    final isBoss = idx == 6;
    // Zone raises the baseline; level index within the zone adds waves.
    final healthScale = 1.0 + (zone - 1) * 0.35 + (idx - 1) * 0.06;
    final speedScale = 1.0 + (zone - 1) * 0.08;
    final waveCount = 3 + idx; // 4..9 waves; boss level has an extra finale.

    // Malware crawlers are introduced from zone 2 onward, growing in share.
    final malwareShare = zone == 1 ? 0.0 : (0.15 + (zone - 2) * 0.12);

    final waves = <WaveConfig>[];
    for (var w = 0; w < waveCount; w++) {
      final drones = 4 + zone + w + idx;
      final malware = (drones * malwareShare).round();
      waves.add(WaveConfig(
        groups: [
          SpawnGroup(type: EnemyType.saboteurDrone, count: drones, spacing: 0.7),
          if (malware > 0)
            SpawnGroup(
                type: EnemyType.malwareCrawler, count: malware, spacing: 1.4),
        ],
        healthScale: healthScale + w * 0.03,
        speedScale: speedScale,
        startDelay: w == 0 ? 5.0 : 4.0,
      ));
    }

    if (isBoss) {
      // Overload Boss Wave: dense, synchronized, multi-type finale.
      final bossDrones = 18 + zone * 4;
      final bossMalware = 6 + zone * 2;
      waves.add(WaveConfig(
        groups: [
          SpawnGroup(
              type: EnemyType.saboteurDrone, count: bossDrones, spacing: 0.25),
          SpawnGroup(
              type: EnemyType.malwareCrawler,
              count: bossMalware,
              spacing: 0.5),
        ],
        healthScale: healthScale + 0.25,
        speedScale: speedScale + 0.05,
        startDelay: 6.0,
        isBossWave: true,
      ));
    }

    const coreIntegrity = 100.0;
    // Rough time budget: sum of start delays + spawn time, with slack.
    final timeBudget = waves.fold<double>(
          0,
          (t, w) =>
              t +
              w.startDelay +
              w.groups.fold<double>(
                  0, (s, g) => s + g.count * g.spacing) +
              4,
        ) *
        0.85;

    return LevelConfig(
      id: id,
      zone: zone,
      indexInZone: idx,
      gridCols: gridCols,
      gridRows: gridRows,
      path: _pathTemplate(zone),
      safeZones: _safeZones(zone),
      waves: waves,
      startingMw: 95 + (idx - 1) * 8, // legacy field, unused by the sim
      coreIntegrity: coreIntegrity,
      lowDamageStarThreshold: 0.25, // keep >=75% integrity for star 2
      timeStarThreshold: timeBudget,
      // Energy-flow seed: enough money to lay down a PV + a first tower, a small
      // BESS charge to start, and a modest battery to force early PV building.
      startMoney: 130 + (idx - 1) * 10,
      startEnergy: 45,
      bessCapacity: 70,
    );
  }
}
