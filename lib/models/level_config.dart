import 'package:flutter/foundation.dart';

import 'enemy_type.dart';

/// A tile coordinate in the isometric grid. Integer col/row.
@immutable
class TileCoord {
  const TileCoord(this.col, this.row);

  final int col;
  final int row;

  @override
  bool operator ==(Object other) =>
      other is TileCoord && other.col == col && other.row == row;

  @override
  int get hashCode => Object.hash(col, row);

  @override
  String toString() => '($col,$row)';
}

/// One enemy group inside a wave: N of a type, spaced [spacing] seconds apart.
@immutable
class SpawnGroup {
  const SpawnGroup({
    required this.type,
    required this.count,
    this.spacing = 0.8,
  });

  final EnemyType type;
  final int count;
  final double spacing;

  factory SpawnGroup.fromJson(Map<String, dynamic> json) => SpawnGroup(
        type: EnemyType.values.byName(json['type'] as String),
        count: json['count'] as int,
        spacing: (json['spacing'] as num?)?.toDouble() ?? 0.8,
      );

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'count': count,
        'spacing': spacing,
      };
}

/// A wave: an ordered list of spawn groups plus health/speed scaling and a
/// flag marking the Zone's climactic Overload Boss Wave.
@immutable
class WaveConfig {
  const WaveConfig({
    required this.groups,
    this.healthScale = 1.0,
    this.speedScale = 1.0,
    this.startDelay = 3.0,
    this.isBossWave = false,
  });

  final List<SpawnGroup> groups;
  final double healthScale;
  final double speedScale;

  /// Seconds of breather before this wave begins spawning.
  final double startDelay;
  final bool isBossWave;

  factory WaveConfig.fromJson(Map<String, dynamic> json) => WaveConfig(
        groups: (json['groups'] as List)
            .map((g) => SpawnGroup.fromJson(g as Map<String, dynamic>))
            .toList(),
        healthScale: (json['healthScale'] as num?)?.toDouble() ?? 1.0,
        speedScale: (json['speedScale'] as num?)?.toDouble() ?? 1.0,
        startDelay: (json['startDelay'] as num?)?.toDouble() ?? 3.0,
        isBossWave: json['isBossWave'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'groups': groups.map((g) => g.toJson()).toList(),
        'healthScale': healthScale,
        'speedScale': speedScale,
        'startDelay': startDelay,
        'isBossWave': isBossWave,
      };
}

/// Fully describes a playable level: grid dimensions, the enemy path (in tile
/// space), where PV panels may go, the wave script, starting economy and the
/// thresholds that decide the second and third star.
@immutable
class LevelConfig {
  const LevelConfig({
    required this.id,
    required this.zone,
    required this.indexInZone,
    required this.gridCols,
    required this.gridRows,
    required this.path,
    required this.safeZones,
    required this.waves,
    required this.startingMw,
    required this.coreIntegrity,
    required this.lowDamageStarThreshold,
    required this.timeStarThreshold,
  });

  final int id;

  /// 1-based zone (1..5).
  final int zone;

  /// 1-based level within its zone (1..6).
  final int indexInZone;

  final int gridCols;
  final int gridRows;

  /// Ordered waypoints enemies follow, in tile coordinates.
  final List<TileCoord> path;

  /// Tiles where PV panels (economy) may be built.
  final Set<TileCoord> safeZones;

  final List<WaveConfig> waves;
  final int startingMw;
  final double coreIntegrity;

  /// Star 2: keep integrity loss at or below this fraction (0..1) of max.
  final double lowDamageStarThreshold;

  /// Star 3: finish all waves within this many seconds.
  final double timeStarThreshold;

  bool get isZoneFinale => indexInZone == 6;

  /// The core sits at the final path waypoint.
  TileCoord get coreTile => path.last;
  TileCoord get spawnTile => path.first;

  factory LevelConfig.fromJson(Map<String, dynamic> json) => LevelConfig(
        id: json['id'] as int,
        zone: json['zone'] as int,
        indexInZone: json['indexInZone'] as int,
        gridCols: json['gridCols'] as int,
        gridRows: json['gridRows'] as int,
        path: (json['path'] as List)
            .map((p) => TileCoord(p[0] as int, p[1] as int))
            .toList(),
        safeZones: (json['safeZones'] as List)
            .map((p) => TileCoord(p[0] as int, p[1] as int))
            .toSet(),
        waves: (json['waves'] as List)
            .map((w) => WaveConfig.fromJson(w as Map<String, dynamic>))
            .toList(),
        startingMw: json['startingMw'] as int,
        coreIntegrity: (json['coreIntegrity'] as num).toDouble(),
        lowDamageStarThreshold:
            (json['lowDamageStarThreshold'] as num).toDouble(),
        timeStarThreshold: (json['timeStarThreshold'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'zone': zone,
        'indexInZone': indexInZone,
        'gridCols': gridCols,
        'gridRows': gridRows,
        'path': path.map((p) => [p.col, p.row]).toList(),
        'safeZones': safeZones.map((p) => [p.col, p.row]).toList(),
        'waves': waves.map((w) => w.toJson()).toList(),
        'startingMw': startingMw,
        'coreIntegrity': coreIntegrity,
        'lowDamageStarThreshold': lowDamageStarThreshold,
        'timeStarThreshold': timeStarThreshold,
      };
}
