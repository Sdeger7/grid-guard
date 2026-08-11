import 'package:flutter/material.dart';

import '../../data/dc_workload.dart';
import '../../data/tower_catalog.dart';
import '../../game/grid_guard_game.dart';
import '../../models/level_state.dart';
import '../../models/tower_type.dart';
import '../theme.dart';

/// The full in-game HUD: a status bar (core + BESS energy + money/score/wave),
/// a facilities row (Data Center / BESS upgrades), a contextual tower-upgrade
/// panel, and the build tray. Rebuilds are driven by [state] (the throttled game
/// snapshot); facility/upgrade actions call the game directly.
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
          if (s != null) _FacilitiesRow(state: s, game: game),
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
            money: s?.money ?? 0,
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
    final net = state.netEnergy;
    final netLabel = '${net >= 0 ? '+' : ''}${net.toStringAsFixed(0)}/s';
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: GGPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniBar(
                    label: 'CORE',
                    fraction: state.integrityFraction,
                    color: state.integrityFraction > 0.5
                        ? GGColors.good
                        : state.integrityFraction > 0.25
                            ? GGColors.accentWarm
                            : GGColors.danger,
                  ),
                  const SizedBox(height: 4),
                  _MiniBar(
                    label: 'BESS ⚡ $netLabel',
                    fraction: state.energyFraction,
                    color: state.energy <= 0.5
                        ? GGColors.danger
                        : net < 0
                            ? GGColors.accentWarm
                            : GGColors.accent,
                    trailing:
                        '${state.energy.toStringAsFixed(0)}/${state.energyCapacity.toStringAsFixed(0)}',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _Stat(
              icon: state.isNight
                  ? Icons.nightlight_round
                  : Icons.wb_sunny_rounded,
              color: state.isNight ? GGColors.accent : GGColors.star,
              label: state.isNight ? '—' : '${(state.sunFactor * 100).round()}%',
              caption: 'SUN',
            ),
            const SizedBox(width: 10),
            _Stat(
              icon: Icons.wind_power_rounded,
              color: GGColors.teal,
              label: '${(state.windFactor * 100).round()}%',
              caption: 'WIND',
            ),
            const SizedBox(width: 10),
            _Stat(
              icon: Icons.attach_money_rounded,
              color: GGColors.good,
              label: '${state.money}',
              caption: 'MONEY',
            ),
            const SizedBox(width: 12),
            _Stat(
              icon: Icons.stacked_line_chart_rounded,
              color: GGColors.ink,
              label: '${state.score}',
              caption: 'SCORE',
            ),
            const SizedBox(width: 12),
            _Stat(
              icon: Icons.waves_rounded,
              color: GGColors.accentWarm,
              label: state.waveNumber == 0
                  ? '—'
                  : state.endless
                      ? '${state.waveNumber}'
                      : '${state.waveNumber}/${state.totalWaves}',
              caption: state.endless ? 'RAID' : 'WAVE',
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.label,
    required this.fraction,
    required this.color,
    this.trailing,
  });
  final String label;
  final double fraction;
  final Color color;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GGText.soft),
            if (trailing != null) Text(trailing!, style: GGText.soft),
          ],
        ),
        const SizedBox(height: 2),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: GGColors.bg,
                border: Border.all(color: GGColors.panelBorder),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ],
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
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 2),
            Text(label, style: GGText.stat),
          ],
        ),
        Text(caption, style: GGText.soft),
      ],
    );
  }
}

/// Data Center + BESS facilities: shows live income/draw/capacity and lets the
/// player spend money to grow them (the core greed-vs-power decision).
class _FacilitiesRow extends StatelessWidget {
  const _FacilitiesRow({required this.state, required this.game});
  final LevelState state;
  final GridGuardGame game;

  @override
  Widget build(BuildContext context) {
    final w = DcWorkloadCatalog.workloads[state.workloadIndex];
    final income = w.income * (1 + 0.35 * (state.dcLevel - 1));
    final draw = w.draw * (1 + 0.25 * (state.dcLevel - 1));
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Row(
        children: [
          Expanded(
            child: _FacilityCard(
              icon: Icons.dns_rounded,
              title: 'DC L${state.dcLevel} · ${w.emoji}${w.name}',
              level: state.dcLevel,
              showLevel: false,
              line:
                  '+${income.toStringAsFixed(0)}\$ · -${draw.toStringAsFixed(0)}⚡ · 🛡${state.security}  (tap to change)',
              statusColor: state.dcPowered ? GGColors.good : GGColors.danger,
              statusText: state.dcPowered ? 'ONLINE' : 'NO POWER',
              cost: state.dcUpgradeCost,
              affordable: state.money >= state.dcUpgradeCost,
              onUpgrade: game.upgradeDc,
              onTapBody: () => _showWorkloadSheet(
                  context, game, state.workloadIndex, state.security),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FacilityCard(
              icon: Icons.battery_charging_full_rounded,
              title: 'BESS',
              level: state.bessLevel,
              line: 'cap ${state.energyCapacity.toStringAsFixed(0)}⚡',
              statusColor: GGColors.accent,
              statusText: '${(state.energyFraction * 100).round()}%',
              cost: state.bessUpgradeCost,
              affordable: state.money >= state.bessUpgradeCost,
              onUpgrade: game.upgradeBess,
            ),
          ),
        ],
      ),
    );
  }
}

class _FacilityCard extends StatelessWidget {
  const _FacilityCard({
    required this.icon,
    required this.title,
    required this.level,
    required this.line,
    required this.statusColor,
    required this.statusText,
    required this.cost,
    required this.affordable,
    required this.onUpgrade,
    this.showLevel = true,
    this.onTapBody,
  });
  final IconData icon;
  final String title;
  final int level;
  final String line;
  final Color statusColor;
  final String statusText;
  final int cost;
  final bool affordable;
  final VoidCallback onUpgrade;
  final bool showLevel;
  final VoidCallback? onTapBody;

  @override
  Widget build(BuildContext context) {
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(showLevel ? '$title  L$level' : title,
                  overflow: TextOverflow.ellipsis,
                  style: GGText.body
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            const SizedBox(width: 4),
            Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: statusColor, shape: BoxShape.circle)),
            const SizedBox(width: 2),
            Text(statusText, style: GGText.soft.copyWith(color: statusColor)),
          ],
        ),
        Text(line, style: GGText.soft, overflow: TextOverflow.ellipsis),
      ],
    );
    return GGPanel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: GGColors.ink),
          const SizedBox(width: 6),
          Expanded(
            child: onTapBody == null
                ? info
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTapBody,
                    child: info,
                  ),
          ),
          GestureDetector(
            onTap: affordable ? onUpgrade : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: affordable ? GGColors.good : GGColors.panelBorder,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.keyboard_double_arrow_up_rounded,
                      size: 12, color: Colors.white),
                  Text('$cost',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet to choose the Data Center's workload — the risk/reward dial.
void _showWorkloadSheet(
    BuildContext context, GridGuardGame game, int current, int security) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: GGColors.panel,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('DATA CENTER WORKLOAD', style: GGText.heading),
                Row(
                  children: [
                    const Icon(Icons.shield_rounded,
                        size: 16, color: GGColors.accent),
                    const SizedBox(width: 3),
                    Text('SEC $security',
                        style: GGText.stat.copyWith(color: GGColors.accent)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
                'Higher-value data pays more — but needs more security and draws more raids.',
                style: GGText.soft),
            const SizedBox(height: 10),
            for (var i = 0; i < DcWorkloadCatalog.workloads.length; i++)
              _WorkloadTile(
                w: DcWorkloadCatalog.workloads[i],
                selected: i == current,
                locked: security < DcWorkloadCatalog.workloads[i].requiredSecurity,
                onTap: () {
                  game.setWorkload(i);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class _WorkloadTile extends StatelessWidget {
  const _WorkloadTile({
    required this.w,
    required this.selected,
    required this.locked,
    required this.onTap,
  });
  final DcWorkload w;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.55 : 1.0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: locked ? null : onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:
                selected ? GGColors.accent.withValues(alpha: 0.10) : GGColors.bg,
            border: Border.all(
                color: selected ? GGColors.accent : GGColors.panelBorder),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Text(w.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(w.name,
                              overflow: TextOverflow.ellipsis,
                              style: GGText.body
                                  .copyWith(fontWeight: FontWeight.w700)),
                        ),
                        if (locked) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.lock_rounded,
                              size: 13, color: GGColors.danger),
                          Text(' SEC ${w.requiredSecurity}',
                              style: GGText.soft.copyWith(color: GGColors.danger)),
                        ],
                      ],
                    ),
                    Text(w.blurb, style: GGText.soft),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('+${w.income.toStringAsFixed(0)}\$/s',
                      style: GGText.soft.copyWith(
                          color: GGColors.good, fontWeight: FontWeight.w700)),
                  Text('-${w.draw.toStringAsFixed(0)}⚡/s',
                      style: GGText.soft.copyWith(color: GGColors.accent)),
                  Text('🔥 ${w.threat.toStringAsFixed(1)}x',
                      style: GGText.soft.copyWith(color: GGColors.danger)),
                ],
              ),
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.check_circle_rounded,
                      color: GGColors.accent, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildTray extends StatelessWidget {
  const _BuildTray({
    required this.money,
    required this.selectedBuild,
    required this.onSelectBuild,
  });
  final int money;
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
                money: money,
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
    required this.money,
    required this.selected,
    required this.onTap,
  });
  final TowerType type;
  final int money;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon {
    switch (type) {
      case TowerType.pvPanel:
        return Icons.solar_power_rounded;
      case TowerType.windTurbine:
        return Icons.wind_power_rounded;
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
    final affordable = money >= cost;
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
                const Icon(Icons.attach_money_rounded,
                    size: 12, color: GGColors.good),
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
              label: Text('Upgrade  \$${selected.upgradeCost}'),
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
