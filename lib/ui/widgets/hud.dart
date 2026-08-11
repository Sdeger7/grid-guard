import 'package:flutter/material.dart';

import '../../data/tower_catalog.dart';
import '../../game/grid_guard_game.dart';
import '../../models/level_state.dart';
import '../../models/tower_type.dart';
import '../theme.dart';

/// The full in-game HUD: a single top status bar, a bottom build tray, and a
/// contextual upgrade panel. Rebuilds are driven by [state] (the throttled game
/// snapshot) and [selectedBuild]/[selected] passed from the game screen.
class Hud extends StatelessWidget {
  const Hud({
    super.key,
    required this.game,
    required this.state,
    required this.selectedBuild,
    required this.selected,
    required this.onSelectBuild,
    required this.onStart,
    required this.onUpgrade,
  });

  final GridGuardGame game;
  final LevelState? state;
  final TowerType? selectedBuild;
  final SelectedStructure? selected;
  final ValueChanged<TowerType?> onSelectBuild;
  final VoidCallback onStart;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final s = state;
    return SafeArea(
      child: Column(
        children: [
          if (s != null) _TopBar(state: s),
          const Spacer(),
          if (s != null && s.bossWaveActive && s.phase == RunPhase.inProgress)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: _BossBanner(),
            ),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: _UpgradePanel(selected: selected!, onUpgrade: onUpgrade),
            ),
          if (s != null && s.phase == RunPhase.building)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _StartButton(onStart: onStart),
            ),
          _BuildTray(
            mw: s?.mw ?? 0,
            selectedBuild: selectedBuild,
            onSelectBuild: onSelectBuild,
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state});
  final LevelState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: GGPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _IntegrityBar(fraction: state.integrityFraction),
            const SizedBox(width: 14),
            _Stat(
              icon: Icons.bolt_rounded,
              color: GGColors.mw,
              label: '${state.mw}',
              caption: 'MW',
            ),
            const SizedBox(width: 14),
            _Stat(
              icon: Icons.stacked_line_chart_rounded,
              color: GGColors.ink,
              label: '${state.score}',
              caption: 'SCORE',
            ),
            const Spacer(),
            _Stat(
              icon: Icons.waves_rounded,
              color: GGColors.accentWarm,
              label: state.waveNumber == 0
                  ? '—'
                  : '${state.waveNumber}/${state.totalWaves}',
              caption: 'WAVE',
            ),
          ],
        ),
      ),
    );
  }
}

class _IntegrityBar extends StatelessWidget {
  const _IntegrityBar({required this.fraction});
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final color = fraction > 0.5
        ? GGColors.good
        : fraction > 0.25
            ? GGColors.accentWarm
            : GGColors.danger;
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('CORE INTEGRITY', style: GGText.soft),
          const SizedBox(height: 3),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: GGColors.bg,
                  border: Border.all(color: GGColors.panelBorder),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fraction,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.label,
    required this.caption,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 3),
            Text(label, style: GGText.stat),
          ],
        ),
        Text(caption, style: GGText.soft),
      ],
    );
  }
}

class _BuildTray extends StatelessWidget {
  const _BuildTray({
    required this.mw,
    required this.selectedBuild,
    required this.onSelectBuild,
  });
  final int mw;
  final TowerType? selectedBuild;
  final ValueChanged<TowerType?> onSelectBuild;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Row(
        children: [
          for (final type in TowerCatalog.buildTray) ...[
            Expanded(
              child: _TowerButton(
                type: type,
                mw: mw,
                selected: selectedBuild == type,
                onTap: () =>
                    onSelectBuild(selectedBuild == type ? null : type),
              ),
            ),
            const SizedBox(width: 8),
          ],
          _InspectButton(
            active: selectedBuild == null,
            onTap: () => onSelectBuild(null),
          ),
        ],
      ),
    );
  }
}

class _TowerButton extends StatelessWidget {
  const _TowerButton({
    required this.type,
    required this.mw,
    required this.selected,
    required this.onTap,
  });
  final TowerType type;
  final int mw;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon {
    switch (type) {
      case TowerType.pvPanel:
        return Icons.solar_power_rounded;
      case TowerType.scissorBarrier:
        return Icons.content_cut_rounded;
      case TowerType.shockTransformer:
        return Icons.flash_on_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = TowerCatalog.of(type);
    final cost = spec.tier(0).cost;
    final affordable = mw >= cost;
    return GestureDetector(
      onTap: onTap,
      child: GGPanel(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        color: selected ? GGColors.accent.withValues(alpha: 0.12) : GGColors.panel,
        borderColor: selected ? GGColors.accent : GGColors.panelBorder,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon,
                color: affordable ? spec.tint : GGColors.panelBorder, size: 24),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, size: 12, color: GGColors.mw),
                Text('$cost',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: affordable ? GGColors.ink : GGColors.danger,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InspectButton extends StatelessWidget {
  const _InspectButton({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GGPanel(
        padding: const EdgeInsets.all(12),
        color: active ? GGColors.accent.withValues(alpha: 0.12) : GGColors.panel,
        borderColor: active ? GGColors.accent : GGColors.panelBorder,
        child: const Icon(Icons.touch_app_rounded,
            color: GGColors.inkSoft, size: 24),
      ),
    );
  }
}

class _UpgradePanel extends StatelessWidget {
  const _UpgradePanel({required this.selected, required this.onUpgrade});
  final SelectedStructure selected;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final maxed = selected.upgradeCost == null;
    return GGPanel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(selected.name, style: GGText.heading),
                Text('Tier ${selected.tier + 1} / ${selected.maxTier + 1}',
                    style: GGText.soft),
              ],
            ),
          ),
          if (maxed)
            const Text('MAX', style: GGText.heading)
          else
            ElevatedButton.icon(
              onPressed: onUpgrade,
              icon: const Icon(Icons.upgrade_rounded, size: 18),
              label: Text('Upgrade  ${selected.upgradeCost} MW'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GGColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
            ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onStart,
      icon: const Icon(Icons.play_arrow_rounded),
      label: const Text('START DEFENSE'),
      style: ElevatedButton.styleFrom(
        backgroundColor: GGColors.good,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _BossBanner extends StatelessWidget {
  const _BossBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: GGColors.danger,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
          SizedBox(width: 6),
          Text('OVERLOAD BOSS WAVE',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}
