import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

/// Every sound effect the game can trigger. Values are asset filenames under
/// `assets/audio/`; they may not exist yet — [AudioService] fails silently on a
/// missing file so the game runs with no audio until real SFX are dropped in.
enum Sfx {
  towerPlace('tower_place.wav'),
  towerFire('tower_fire.wav'),
  enemyDeath('enemy_death.wav'),
  coreDamage('core_damage.wav'),
  waveStart('wave_start.wav'),
  levelWin('level_win.wav'),
  levelLose('level_lose.wav'),
  uiTap('ui_tap.wav');

  const Sfx(this.file);
  final String file;
}

/// Thin wrapper over flame_audio that centralises SFX hook points. The rest of
/// the game calls [play]; whether audio is wired, cached or missing is this
/// service's problem, not the caller's.
class AudioService {
  bool _muted = false;
  bool _ready = false;

  bool get muted => _muted;
  set muted(bool value) => _muted = value;

  /// Pre-warm the audio cache. Safe to call even when no files exist — any
  /// failures are swallowed so startup never breaks on missing placeholders.
  Future<void> preload() async {
    try {
      await FlameAudio.audioCache.loadAll(Sfx.values.map((s) => s.file).toList());
      _ready = true;
    } catch (e) {
      debugPrint('[Audio] preload skipped (placeholder assets missing): $e');
      _ready = false;
    }
  }

  void play(Sfx sfx, {double volume = 0.8}) {
    if (_muted || !_ready) return;
    try {
      FlameAudio.play(sfx.file, volume: volume);
    } catch (e) {
      debugPrint('[Audio] play failed for ${sfx.file}: $e');
    }
  }
}
