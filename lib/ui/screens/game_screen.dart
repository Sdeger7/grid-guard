import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/levels.dart';
import '../../data/premium_packages.dart';
import '../../data/skins.dart';
import '../../data/streak.dart';
import '../../game/grid_guard_game.dart' as gg;
import '../../models/base_save.dart';
import '../../models/level_config.dart';
import '../../models/level_state.dart';
import '../../models/tower_type.dart';
import '../../services/app_providers.dart';
import '../../services/audio_service.dart' as audio;
import '../../services/monetization_service.dart';
import '../theme.dart';
import '../widgets/hud.dart';
import '../widgets/dawn_panel.dart';
import '../widgets/level_end.dart';
import '../widgets/offline_panel.dart';
import '../../data/challenge.dart';
import '../widgets/challenge_sheet.dart';
import '../widgets/city_sheet.dart';
import '../widgets/report_sheet.dart';
import '../widgets/site_menu.dart';
import '../widgets/streak_panel.dart';
import '../widgets/speedup_sheet.dart';
import '../widgets/tutorial_overlay.dart';
import 'guide_screen.dart';
import 'premium_screen.dart';

/// Hosts one level: the Flame [gg.GridGuardGame] plus the Flutter HUD and
/// win/lose overlays. Owns the glue between the game's callbacks and Riverpod
/// (profile persistence, monetization, audio).
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, required this.config, this.challenge = false});

  final LevelConfig config;

  /// A weekly challenge run: its own save slot, no perks, no purchases, and a
  /// fixed length. Everyone's is identical, which is the only reason comparing
  /// them means anything.
  final bool challenge;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  late gg.GridGuardGame _game;

  /// Autosave cadence. The site is permanent, so losing more than a few
  /// seconds of progress to a killed app is not acceptable.
  static const _autosaveInterval = Duration(seconds: 5);
  Timer? _autosaveTimer;
  Timer? _weatherTimer;
  OfflineReport? _offline;
  ({int raids, int damaged, int destroyed, bool blackout})? _missedRaids;
  gg.DawnReport? _dawn;

  /// Today's streak day, set on the first launch of each day.
  int? _streakDay;

  /// Guards the one-time challenge payout.
  bool _settled = false;

  LevelState? _snapshot;
  gg.SelectedStructure? _selected;
  TowerType? _selectedBuild;
  LevelResult? _result;
  bool _continueUsed = false;
  bool _resultApplied = false;

  /// Set once the player closes the coach; keeps it gone for the rest of the run.
  bool _tipsDismissed = false;

  // Pinch/pan bookkeeping between onScaleUpdate callbacks.
  double _gestureScale = 1;
  Offset _gestureFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    // Survival is one continuous site: reload whatever the player left behind.
    final save = widget.config.endless
        ? ref.read(saveServiceProvider).loadBase(challenge: widget.challenge)
        : null;
    // Whatever the player is wearing, resolved once at launch.
    final worn = <SkinSlot, Skin>{};
    final equipped = ref.read(profileProvider).equippedSkins;
    for (final slot in SkinSlot.values) {
      final id = equipped[slot.name];
      worn[slot] =
          id == null ? SkinCatalog.defaultFor(slot) : SkinCatalog.byId(id);
    }

    _game = gg.GridGuardGame(
      config: widget.config,
      initialBase: save,
      skins: worn,
      challenge: widget.challenge,
      // Nothing bought applies inside a challenge run.
      perks: widget.challenge
          ? const PremiumPackage(
              id: '_none', name: '', emoji: '', price: 0, blurb: '')
          : PremiumCatalog.effectiveOf(
              ref.read(profileProvider).ownedPackages),
      hasGridPass: !widget.challenge &&
          ref.read(monetizationServiceProvider).isProductPurchased('grid_pass'),
      callbacks: gg.GameCallbacks(
        onSnapshot: _onSnapshot,
        onFinished: _onFinished,
        onSfx: _onSfx,
        onSelection: (s) => setState(() => _selected = s),
      ),
    );

    if (widget.config.endless) {
      WidgetsBinding.instance.addObserver(this);
      // The check-in runs once per real day, before anything else claims the
      // screen.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final day = await ref.read(profileProvider.notifier).touchStreak();
        if (!mounted || day == null) return;
        setState(() => _streakDay = day);
      });
      _autosaveTimer = Timer.periodic(_autosaveInterval, (_) => _saveBase());
      // Real conditions over the real site, refreshed occasionally and cached.
      _refreshWeather();
      _weatherTimer =
          Timer.periodic(const Duration(minutes: 10), (_) => _refreshWeather());
      if (save != null && !save.isEmpty) {
        // Report what the site produced while the app was closed, once the
        // game has finished rebuilding the base.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // What the site earned, and what it had to defend on its own.
          final report = _game.computeOfflineEarnings(save);
          final raids = _game.resolveMissedRaids(save.savedAtMs);
          _game.scheduleRaidWindows();
          if (!mounted) return;
          if (report.isWorthShowing) _game.applyOfflineEarnings(report);
          if (!report.isWorthShowing && raids.raids == 0) return;
          setState(() {
            _offline = report;
            _missedRaids = raids;
          });
        });
      }
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _weatherTimer?.cancel();
    if (widget.config.endless) {
      WidgetsBinding.instance.removeObserver(this);
      _saveBase();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding the app is the most common way a session ends on a phone.
    if (state != AppLifecycleState.resumed) _saveBase();
  }

  /// Settles a finished week: place the run in the field, pay what that
  /// position is worth out of the pool.
  Future<void> _settleChallenge() async {
    final week = ChallengeCatalog.current();
    final score = ChallengeCatalog.scoreFor(
      baseValue: _game.baseValue,
      money: _game.money.floor(),
      blackouts: _game.blackoutCount,
      watt: _game.coinsEarned,
    );
    await ref
        .read(profileProvider.notifier)
        .recordChallengeScore(week.week, score);

    final entered =
        ref.read(profileProvider).challengeEntered[week.week] == true;
    if (!entered) return;

    final field = ChallengeCatalog.benchmarkField(week);
    final rank = ChallengeCatalog.rankOf(score, field);
    final prize =
        ChallengeCatalog.prizeFor(rank: rank, field: field.length + 1);
    if (prize > 0) {
      await ref
          .read(profileProvider.notifier)
          .awardChallengeReward(week.week, prize);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(prize > 0
            ? 'Week over — finished #$rank. ₵${prize.toStringAsFixed(2)} '
                'from the pool.'
            : 'Week over — finished #$rank, outside the places.'),
      ),
    );
  }

  Future<void> _refreshWeather() async {
    final service = ref.read(weatherServiceProvider);
    if (service == null) return;
    final city = _game.city;
    final live = await service.conditionsFor(
      cityId: city.id,
      latitude: city.latitude,
      longitude: city.longitude,
    );
    if (!mounted || live == null) return;
    _game.liveWeather = live;
  }

  void _saveBase() {
    if (!widget.config.endless) return;
    ref
        .read(saveServiceProvider)
        .saveBase(_game.captureSave(), challenge: widget.challenge);
  }

  void _onSnapshot(LevelState state) {
    _snapshot = state;
    if (!mounted) return;
    // A challenge run settles the moment its last day is done.
    if (widget.challenge && _game.challengeComplete && !_settled) {
      _settled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _settleChallenge());
    }

    // The game raises a dawn report once per morning; claim it for the UI.
    final dawn = _game.pendingDawn;
    if (dawn != null) {
      _game.pendingDawn = null;
      _dawn = dawn;
    }
    // The first snapshot fires during the game's onLoad (widget-build phase),
    // and later ones arrive from the game loop. Defer the rebuild to the next
    // frame so we never call setState (or touch a provider) mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
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
    if (_resultApplied) return;
    _resultApplied = true;

    // Endless runs bank mined WATT and update records; campaign levels award
    // stars/credits as before.
    if (widget.config.endless) {
      await ref.read(profileProvider.notifier).bankRunResults(
            coins: _game.coinsEarned,
            raid: _game.raidCount,
            score: result.finalScore,
          );
    } else if (result.isWin) {
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

  /// End panels still offer a way out; with the site as the app's root there
  /// is nothing to pop back to, so this just dismisses the panel.
  void _menu() => setState(() => _result = null);

  /// Button zoom pivots on the middle of the viewport.
  Vector2 _viewCentre() {
    final s = MediaQuery.sizeOf(context);
    return Vector2(s.width / 2, s.height / 2);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final endless = widget.config.endless;
    final showSurvivalEnd = result != null && endless;
    final showWin = result != null && !endless && result.isWin;
    final showLose = result != null && !endless && !result.isWin;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _game.handleTapAt(
                Vector2(details.localPosition.dx, details.localPosition.dy),
              ),
              // Pinch to zoom, drag to pan. Tap still wins the gesture arena
              // when the finger doesn't travel, so placing stays a single tap.
              onScaleStart: (d) {
                _gestureScale = 1;
                _gestureFocal = d.localFocalPoint;
              },
              onScaleUpdate: (d) {
                final focal = d.localFocalPoint;
                if (d.pointerCount >= 2 && d.scale > 0 && _gestureScale > 0) {
                  _game.zoomBy(d.scale / _gestureScale,
                      Vector2(focal.dx, focal.dy));
                  _gestureScale = d.scale;
                }
                final move = focal - _gestureFocal;
                _gestureFocal = focal;
                if (move != Offset.zero) {
                  _game.panBy(Vector2(move.dx, move.dy));
                }
              },
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
              onRepair: _game.repairSelected,
              onRepairAll: _game.repairAll,
              onAbilityUsed: () => setState(() {}),
              onOpenStore: () => showSpeedupSheet(
                  context, _game, ref.read(monetizationServiceProvider)),
            ),
          ),
          // Coaching sits above the HUD but never over an end-of-run panel.
          if (_snapshot != null && result == null)
            Positioned.fill(
              child: SafeArea(
                child: TutorialOverlay(
                  state: _snapshot!,
                  dismissed: _tipsDismissed,
                  onDismiss: () => setState(() => _tipsDismissed = true),
                ),
              ),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu_book_rounded,
                        color: GGColors.inkSoft),
                    tooltip: 'How the site works',
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const GuideScreen())),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded,
                        color: GGColors.inkSoft),
                    tooltip: 'Site menu',
                    onPressed: () => showSiteMenu(
                      context,
                      ref,
                      onOpenServices: () => showSpeedupSheet(context, _game,
                          ref.read(monetizationServiceProvider)),
                      onOpenReport: () => showReportSheet(context, _game),
                      onOpenChallenge: () =>
                          showChallengeSheet(context, ref, _game),
                      onOpenCities: () => showCitySheet(context, _game,
                          onChanged: () {
                            _refreshWeather();
                            setState(() {});
                          }),
                      onAbandon: () {
                        _game.abandonSite();
                        _selectBuild(null);
                        setState(() {
                          _dawn = null;
                          _offline = null;
                          _result = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Explicit zoom controls, for players who'd rather not pinch.
          Positioned(
            right: 8,
            bottom: 150,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ViewButton(
                    icon: Icons.add_rounded,
                    onTap: () => _game.zoomBy(1.25, _viewCentre()),
                  ),
                  const SizedBox(height: 6),
                  _ViewButton(
                    icon: Icons.remove_rounded,
                    onTap: () => _game.zoomBy(0.8, _viewCentre()),
                  ),
                  const SizedBox(height: 6),
                  _ViewButton(
                    icon: Icons.center_focus_strong_rounded,
                    onTap: _game.resetView,
                  ),
                ],
              ),
            ),
          ),
          if (_streakDay != null)
            StreakPanel(
              day: _streakDay!,
              onClaim: () async {
                final reward = StreakCalendar.rewardFor(_streakDay!);
                await ref.read(profileProvider.notifier).claimStreak();
                _game.grantCash(reward.cash.toDouble());
                if (mounted) setState(() => _streakDay = null);
              },
            ),
          if (_dawn != null && _offline == null && _streakDay == null)
            DawnPanel(
              report: _dawn!,
              onClose: () => setState(() => _dawn = null),
            ),
          if (_offline != null && _streakDay == null)
            OfflinePanel(
              report: _offline!,
              raids: _missedRaids,
              onWatchToDouble: widget.challenge
                  ? null
                  : () async {
                      final ok = await ref
                          .read(monetizationServiceProvider)
                          .showRewardedAd(AdPlacements.doubleOffline);
                      if (!ok || !mounted) return;
                      _game.grantCash(_offline!.money.toDouble());
                      setState(() {
                        _offline = null;
                        _missedRaids = null;
                      });
                    },
              onClose: () => setState(() {
                _offline = null;
                _missedRaids = null;
              }),
            ),
          if (showSurvivalEnd)
            SurvivalEndPanel(
              raid: _game.raidCount,
              score: result.finalScore,
              coins: _game.coinsEarned,
              bestRaid: ref.watch(profileProvider).bestRaid,
              onRetry: _retry,
              onMenu: _menu,
              onPremium: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PremiumScreen())),
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

/// A small translucent map-control button (zoom in/out, recentre).
class _ViewButton extends StatelessWidget {
  const _ViewButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GGColors.panel.withValues(alpha: 0.92),
      shape: const CircleBorder(
        side: BorderSide(color: GGColors.panelBorder),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: GGColors.ink),
        ),
      ),
    );
  }
}
