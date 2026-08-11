import 'dart:math' as math;

import '../../models/enemy_type.dart';
import '../../models/level_config.dart';

/// One scheduled enemy emission at an absolute time from run start.
class _Spawn {
  _Spawn(this.time, this.type, this.healthScale, this.speedScale, this.wave);
  final double time;
  final EnemyType type;
  final double healthScale;
  final double speedScale;
  final int wave;
}

class _WaveStart {
  _WaveStart(this.time, this.waveNumber, this.isBoss);
  final double time;
  final int waveNumber;
  final bool isBoss;
}

/// Turns a level's [WaveConfig] list into a single absolute-time schedule and
/// plays it back as the run clock advances. Deterministic and self-contained:
/// it emits spawn/wave-start callbacks; the game decides what to build from them.
class WaveSpawner {
  WaveSpawner(
    List<WaveConfig> waves, {
    required this.onSpawn,
    required this.onWaveStart,
  }) {
    _compile(waves);
  }

  /// Called when an enemy should be created, with its already-scaled multipliers.
  final void Function(EnemyType type, double healthScale, double speedScale)
      onSpawn;

  /// Called at the moment a wave begins spawning.
  final void Function(int waveNumber, bool isBoss) onWaveStart;

  final List<_Spawn> _schedule = [];
  final List<_WaveStart> _waveStarts = [];

  double _clock = 0;
  int _spawnCursor = 0;
  int _waveCursor = 0;

  int get totalWaves => _waveStarts.length;

  /// True once every scheduled enemy has been emitted (the game still waits for
  /// them to be cleared before declaring victory).
  bool get allSpawned => _spawnCursor >= _schedule.length;

  void _compile(List<WaveConfig> waves) {
    var t = 0.0;
    for (var wi = 0; wi < waves.length; wi++) {
      final w = waves[wi];
      t += w.startDelay;
      _waveStarts.add(_WaveStart(t, wi + 1, w.isBossWave));
      var waveEnd = t;
      for (final g in w.groups) {
        for (var k = 0; k < g.count; k++) {
          final st = t + k * g.spacing;
          _schedule.add(
              _Spawn(st, g.type, w.healthScale, w.speedScale, wi + 1));
          waveEnd = math.max(waveEnd, st);
        }
      }
      // Next wave's startDelay is measured from the end of this wave's spawns.
      t = waveEnd;
    }
    _schedule.sort((a, b) => a.time.compareTo(b.time));
  }

  void tick(double dt) {
    _clock += dt;
    while (_waveCursor < _waveStarts.length &&
        _waveStarts[_waveCursor].time <= _clock) {
      final ws = _waveStarts[_waveCursor];
      onWaveStart(ws.waveNumber, ws.isBoss);
      _waveCursor++;
    }
    while (_spawnCursor < _schedule.length &&
        _schedule[_spawnCursor].time <= _clock) {
      final s = _schedule[_spawnCursor];
      onSpawn(s.type, s.healthScale, s.speedScale);
      _spawnCursor++;
    }
  }
}
