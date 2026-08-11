import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/levels.dart';
import '../../game/grid_guard_game.dart' as gg;
import '../../models/level_config.dart';
import '../../models/level_state.dart';
import '../../models/tower_type.dart';
import '../../services/app_providers.dart';
import '../../services/audio_service.dart' as audio;
import '../../services/monetization_service.dart';
import '../theme.dart';
import '../widgets/hud.dart';
import '../widgets/level_end.dart';

/// Hosts one level: the Flame [gg.GridGuardGame] plus the Flutter HUD and
/// win/lose overlays. Owns the glue between the game's callbacks and Riverpod
/// (profile persistence, monetization, audio).
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, required this.config});

  final LevelConfig config;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late gg.GridGuardGame _game;

  LevelState? _snapshot;
  gg.SelectedStructure? _selected;
  TowerType? _selectedBuild;
  LevelResult? _result;
  bool _continueUsed = false;
  bool _resultApplied = false;

  @override
  void initState() {
    super.initState();
    _game = gg.GridGuardGame(
      config: widget.config,
      callbacks: gg.GameCallbacks(
        onSnapshot: _onSnapshot,
        onFinished: _onFinished,
        onSfx: _onSfx,
        onSelection: (s) => setState(() => _selected = s),
      ),
    );
  }

  void _onSnapshot(LevelState state) {
    // Keep the shared provider in sync too, in case other widgets watch it.
    ref.read(levelStateProvider.notifier).state = state;
    if (mounted) setState(() => _snapshot = state);
  }

  void _onSfx(gg.Sfx sfx) {
    ref.read(audioServiceProvider).play(_mapSfx(sfx));
  }

  audio.Sfx _mapSfx(gg.Sfx sfx) {
    switch (sfx) {
      case gg.Sfx.towerPlace:
        return audio.Sfx.towerPlace;
      case gg.Sfx.towerFire:
        return audio.Sfx.towerFire;
      case gg.Sfx.enemyDeath:
        return audio.Sfx.enemyDeath;
      case gg.Sfx.coreDamage:
        return audio.Sfx.coreDamage;
      case gg.Sfx.waveStart:
        return audio.Sfx.waveStart;
      case gg.Sfx.levelWin:
        return audio.Sfx.levelWin;
      case gg.Sfx.levelLose:
        return audio.Sfx.levelLose;
    }
  }

  Future<void> _onFinished(LevelResult result) async {
    setState(() => _result = result);
    if (result.isWin && !_resultApplied) {
      _resultApplied = true;
      await ref.read(profileProvider.notifier).applyLevelResult(
            result,
            zone: widget.config.zone,
            indexInZone: widget.config.indexInZone,
          );
    }
  }

  void _selectBuild(TowerType? type) {
    setState(() => _selectedBuild = type);
    _game.setBuildSelection(type);
  }

  Future<bool> _watchDoubleReward() async {
    final ok = await ref
        .read(monetizationServiceProvider)
        .showRewardedAd(AdPlacements.doubleReward);
    if (ok && _result != null) {
      // Base credits were already granted on win; add a second copy to double.
      await ref
          .read(profileProvider.notifier)
          .awardBonusCredits(_result!.baseGridCredits);
    }
    return ok;
  }

  Future<bool> _continueRun() async {
    final ok = await ref
        .read(monetizationServiceProvider)
        .showRewardedAd(AdPlacements.continueRun);
    if (ok) {
      setState(() {
        _continueUsed = true;
        _result = null;
      });
      _game.reviveCore();
    }
    return ok;
  }

  Future<void> _next() async {
    // Interstitial pacing: only when due (every ~3 levels, never on level 1).
    final due =
        ref.read(profileProvider.notifier).consumeInterstitialSlotIfDue();
    if (due) {
      await ref.read(monetizationServiceProvider).showInterstitial();
    }
    if (!mounted) return;
    final nextId = widget.config.id + 1;
    final hasNext = nextId <= LevelCatalog.levels.length;
    if (hasNext) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => GameScreen(config: LevelCatalog.byId(nextId)),
      ));
    } else {
      Navigator.of(context).pop();
    }
  }

  void _retry() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => GameScreen(config: widget.config),
    ));
  }

  void _menu() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final showWin = result != null && result.isWin;
    final showLose = result != null && !result.isWin;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _game.handleTapAt(
                Vector2(details.localPosition.dx, details.localPosition.dy),
              ),
              child: GameWidget(game: _game),
            ),
          ),
          Positioned.fill(
            child: Hud(
              game: _game,
              state: _snapshot,
              selectedBuild: _selectedBuild,
              selected: _selected,
              onSelectBuild: _selectBuild,
              onStart: () {
                _selectBuild(null);
                _game.startWaves();
              },
              onUpgrade: _game.upgradeSelected,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: GGColors.inkSoft),
                onPressed: _menu,
              ),
            ),
          ),
          if (showWin)
            WinPanel(
              result: result,
              onWatchDoubleReward: _watchDoubleReward,
              onNext: _next,
              onMenu: _menu,
            ),
          if (showLose)
            LosePanel(
              canContinue: !_continueUsed,
              onContinue: _continueRun,
              onRetry: _retry,
              onMenu: _menu,
            ),
        ],
      ),
    );
  }
}
