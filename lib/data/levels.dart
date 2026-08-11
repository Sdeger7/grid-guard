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

  /// Two S-shaped path templates; zone parity picks one, so the map reads
  /// differently across zones while staying axis-aligned for barrier placement.
  static List<TileCoord> _pathTemplate(int zone) {
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

  /// Safe zones (PV panel / Shock Transformer sites) flank the path.
  static Set<TileCoord> _safeZones(int zone) {
    // The Set itself can't be `const` (TileCoord overrides ==/hashCode), but the
    // individual elements are compile-time constants.
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
      startingMw: 120 + (idx - 1) * 10,
      coreIntegrity: coreIntegrity,
      lowDamageStarThreshold: 0.25, // keep >=75% integrity for star 2
      timeStarThreshold: timeBudget,
    );
  }
}
