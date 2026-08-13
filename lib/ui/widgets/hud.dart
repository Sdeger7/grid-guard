import 'package:flutter/material.dart';

import '../../data/dc_workload.dart';
import '../../data/grid_market.dart';
import '../../data/tower_catalog.dart';
import '../../game/components/facility_component.dart';
import '../../game/grid_guard_game.dart';
import '../../models/level_state.dart';
import '../../models/tower_type.dart';
import '../theme.dart';
import 'ability_bar.dart';
import 'grid_sheet.dart';
import 'report_sheet.dart';

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
    required this.onRepair,
    required this.onRepairAll,
    required this.onOpenStore,
    required this.onAbilityUsed,
  });

  final GridGuardGame game;
  final LevelState? state;
  final TowerType? selectedBuild;
  final SelectedStructure? selected;
  final ValueChanged<TowerType?> onSelectBuild;
  final VoidCallback onStart;
  final VoidCallback onUpgrade;
  final VoidCallback onRepair;
  final VoidCallback onRepairAll;

  /// Opens the real-money services sheet.
  final VoidCallback onOpenStore;

  /// Called after an ability fires, so the HUD refreshes its cooldowns.
  final VoidCallback onAbilityUsed;

  @override
  Widget build(BuildContext context) {
    final s = state;
    return SafeArea(
      child: Column(
        children: [
          if (s != null) _TopBar(state: s, game: game, onOpenStore: onOpenStore),
          if (s != null) _FacilitiesRow(state: s, game: game),
          if (s != null) _DcChips(game: game, security: s.security),
          const Spacer(),
          if (s != null && s.bossWaveActive && s.phase == RunPhase.inProgress)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: _BossBanner(),
            ),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: _UpgradePanel(
                  selected: selected!,
                  money: s?.money ?? 0,
                  onUpgrade: onUpgrade,
                  onRepair: onRepair),
            ),
          if (s != null && s.damagedCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              child: _RepairAllBar(state: s, onRepairAll: onRepairAll),
            ),
          if (s != null && s.phase == RunPhase.building)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _StartButton(onStart: onStart),
            ),
          // Manual controls sit directly above the tray: during a raid your
          // thumb is already down there.
          if (s != null && s.phase == RunPhase.inProgress)
            AbilityBar(game: game, onUsed: onAbilityUsed),
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
  const _TopBar(
      {required this.state, required this.game, required this.onOpenStore});
  final LevelState state;
  final GridGuardGame game;
  final VoidCallback onOpenStore;

  @override
  Widget build(BuildContext context) {
    final net = state.netEnergy;
    final netLabel = '${net >= 0 ? '+' : ''}${net.toStringAsFixed(0)}/s';
    // Bars stay pinned; the stat strip scrolls so a narrow phone never clips it.
    final stats = <Widget>[
      // Day number first: it is the run's real progress marker, and the
      // forecast beside it tells the player what today's grid will be like.
      _Stat(
        icon: Icons.calendar_today_rounded,
        color: GGColors.ink,
        label: '${state.dayNumber}',
        caption: state.isNight ? 'NIGHT' : 'DAY',
      ),
      if (state.eventEmoji != '·')
        _Stat(
          icon: Icons.campaign_rounded,
          color: GGColors.accentWarm,
          label: state.eventEmoji,
          caption: state.eventName.split(' ').first.toUpperCase(),
        ),
      _Stat(
        icon: Icons.cloud_queue_rounded,
        color: GGColors.teal,
        label: state.weatherEmoji,
        caption: state.weatherName.toUpperCase(),
      ),
      _Stat(
        icon: state.isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded,
        color: state.isNight ? GGColors.accent : GGColors.star,
        label: state.isNight ? '—' : '${(state.sunFactor * 100).round()}%',
        // Real sunrise and sunset for the site's province today, so the player
        // can see the season closing in on them.
        caption: state.isNight
            ? '↑${state.sunriseLabel}'
            : '↓${state.sunsetLabel}',
      ),
      _Stat(
        icon: Icons.wind_power_rounded,
        color: GGColors.teal,
        label: '${(state.windFactor * 100).round()}%',
        caption: 'WIND',
      ),
      // With an Intel Center up, tonight stops being a coin flip.
      if (state.forecastRange > 0)
        _Stat(
          icon: Icons.radar_rounded,
          color: state.tonightRaided ? GGColors.danger : GGColors.good,
          label: state.tonightRaided
              ? (state.tonightWeight > 1.1 ? 'HEAVY' : 'RAID')
              : 'QUIET',
          // The confidence is part of the reading: at 40% it is barely a hint.
          caption: '${(state.forecastAccuracy * 100).round()}% SURE',
        ),
      // The market price is a live decision, not decoration: tapping it turns
      // grid buying on and off.
      _Stat(
        icon: Icons.electric_meter_rounded,
        color: GridMarket.isPeakNow()
            ? GGColors.accentWarm
            : state.gridImporting
                ? GGColors.accent
                : GGColors.inkSoft,
        label: '${state.gridPrice.toStringAsFixed(2)}M',
        caption: GridMarket.isPeakNow()
            ? 'PEAK ${GridMarket.minutesToPeakEdge()}m'
            : state.gridContracts > 0
            ? '${state.gridContracts} DEAL'
            : state.gridImporting
                ? 'BUYING'
                : GridMarket.bandFor(state.gridPrice),
        onTap: () => showGridSheet(context, game),
      ),
      _Stat(
        icon: Icons.paid_rounded,
        color: state.netMoneyRate >= 0 ? GGColors.good : GGColors.danger,
        label: '${state.money}M',
        // The balance is a whole number that only moves every few seconds when
        // the site is near break-even, so the rate is what the player actually
        // needs to read: is this site solvent or bleeding?
        caption: '${state.netMoneyRate >= 0 ? '+' : ''}'
            '${state.netMoneyRate.toStringAsFixed(1)}/s',
        onTap: () => showReportSheet(context, game),
      ),
      _Stat(
        icon: Icons.savings_rounded,
        color: GGColors.amber,
        label: '₵${state.coins.toStringAsFixed(3)}',
        caption: 'WATT ⇄',
        onTap: () => _showExchangeSheet(context, game, state.coins),
      ),
      _Stat(
        icon: Icons.local_fire_department_rounded,
        color: GGColors.danger,
        // Show the climb while heat catches up with a newly accepted contract,
        // so the rise is something the player can see coming and prepare for.
        label: state.threatTarget > state.threat + 0.05
            ? '${state.threat.toStringAsFixed(1)}→'
                '${state.threatTarget.toStringAsFixed(1)}x'
            : '${state.threat.toStringAsFixed(1)}x',
        caption: 'THREAT',
      ),
      _Stat(
        icon: Icons.stacked_line_chart_rounded,
        color: GGColors.ink,
        label: '${state.score}',
        caption: 'SCORE',
      ),
      _Stat(
        icon: Icons.storefront_rounded,
        color: GGColors.accent,
        label: '⏩',
        caption: 'SPEED UP',
        onTap: onOpenStore,
      ),
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
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: GGPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            const SizedBox(height: 3),
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
            const SizedBox(height: 6),
            SizedBox(
              // Tall enough for the tappable stats, which carry padding.
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: stats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) => stats[i],
              ),
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
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String caption;

  /// Set on stats that are also a control (WATT opens the exchange).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = _content();
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: content,
      ),
    );
  }

  Widget _content() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
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

/// Grid summary + global workload picker. BESS/Data Centers are built on the
/// map now; this row shows their aggregate output and the current DC workload
/// (tap to change).
class _FacilitiesRow extends StatelessWidget {
  const _FacilitiesRow({required this.state, required this.game});
  final LevelState state;
  final GridGuardGame game;

  @override
  Widget build(BuildContext context) {
    final w = DcWorkloadCatalog.workloads[state.workloadIndex];
    final powered = state.dcPowered;
    final statusColor = state.dataCenterCount == 0 || state.dcLoadFraction <= 0
        ? GGColors.danger
        : powered
            ? GGColors.good
            : GGColors.accentWarm;
    final statusText = state.dataCenterCount == 0
        ? 'NO DC'
        : powered
            ? 'ONLINE'
            : state.dcLoadFraction > 0.02
                // Half-fed machines earn half as much; say so rather than
                // claiming they have stopped.
                ? 'BROWNOUT ${(state.dcLoadFraction * 100).round()}%'
                : 'NO POWER';
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showWorkloadSheet(
            context, game, state.workloadIndex, state.security),
        child: GGPanel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.dns_rounded, size: 16, color: GGColors.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text('${w.emoji} ${w.name}',
                              overflow: TextOverflow.ellipsis,
                              style: GGText.body.copyWith(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                color: statusColor, shape: BoxShape.circle)),
                        const SizedBox(width: 2),
                        Text(statusText,
                            style: GGText.soft.copyWith(color: statusColor)),
                      ],
                    ),
                    Text(
                      'DC ×${state.dataCenterCount} · +${state.dcIncome.toStringAsFixed(0)}M -${state.operatingCost.toStringAsFixed(0)}M/s upkeep · -${state.dcDraw.toStringAsFixed(0)}⚡  ·  🔋${state.energyCapacity.toStringAsFixed(0)}⚡  ·  🛡${state.security}',
                      style: GGText.soft,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.tune_rounded, size: 18, color: GGColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

/// One chip per Data Center. Each machine books its own contract, so each
/// needs its own control — tapping DC 2 changes what DC 2 runs, nothing else.
class _DcChips extends StatelessWidget {
  const _DcChips({required this.game, required this.security});

  final GridGuardGame game;
  final int security;

  @override
  Widget build(BuildContext context) {
    final dcs = game.dataCenters;
    if (dcs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: dcs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final dc = dcs[i];
            final w = game.workloadOf(dc);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showWorkloadSheet(
                  context, game, dc.workloadIndex, security,
                  target: dc),
              child: GGPanel(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                borderColor:
                    w.minesCoins ? GGColors.amber : GGColors.panelBorder,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('DC ${dc.dcIndex + 1}',
                        style: GGText.soft
                            .copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Text(w.emoji),
                    const SizedBox(width: 4),
                    Text(
                      w.minesCoins
                          ? '₵WATT'
                          : '+${w.income.toStringAsFixed(0)}M',
                      style: GGText.soft.copyWith(
                        fontWeight: FontWeight.w700,
                        color:
                            w.minesCoins ? GGColors.amber : GGColors.good,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


/// Bottom sheet to choose the Data Center's workload — the risk/reward dial.
/// Books work. With [target] set, it books that one machine; without it, the
/// choice applies to the whole site.
void _showWorkloadSheet(
    BuildContext context, GridGuardGame game, int current, int security,
    {FacilityComponent? target}) {
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
                Text(
                    target == null
                        ? 'ALL DATA CENTERS'
                        : 'DC ${target.dcIndex + 1} WORKLOAD',
                    style: GGText.heading),
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
            Text(
                target == null
                    ? 'Books the same contract on every machine. Higher-value '
                        'data pays more, needs more security, and draws more '
                        'raids.'
                    : 'Each machine runs its own contract — mine on one, host '
                        'bank records on another. The hottest job on site sets '
                        'the attention you get.',
                style: GGText.soft),
            const SizedBox(height: 10),
            for (var i = 0; i < DcWorkloadCatalog.workloads.length; i++)
              _WorkloadTile(
                w: DcWorkloadCatalog.workloads[i],
                selected: i == current,
                locked:
                    security < DcWorkloadCatalog.workloads[i].requiredSecurity,
                onTap: () {
                  if (target == null) {
                    game.setWorkload(i);
                  } else {
                    game.setWorkloadFor(target, i);
                  }
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
            color: selected
                ? GGColors.accent.withValues(alpha: 0.10)
                : GGColors.bg,
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
                              style:
                                  GGText.soft.copyWith(color: GGColors.danger)),
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
                  Text('+${w.income.toStringAsFixed(0)}M/s',
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
    // Fixed-width buttons in a horizontal scroller: six units fit any phone,
    // and the inspect toggle stays pinned on the right.
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 62,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: TowerCatalog.buildTray.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final type = TowerCatalog.buildTray[i];
                  return SizedBox(
                    width: 70,
                    child: _TowerButton(
                      type: type,
                      money: money,
                      selected: selectedBuild == type,
                      onTap: () =>
                          onSelectBuild(selectedBuild == type ? null : type),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
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
      case TowerType.bess:
        return Icons.battery_charging_full_rounded;
      case TowerType.dataCenter:
        return Icons.dns_rounded;
      case TowerType.droneBay:
        return Icons.flight_takeoff_rounded;
      case TowerType.scissorBarrier:
        return Icons.content_cut_rounded;
      case TowerType.shockTransformer:
        return Icons.flash_on_rounded;
      case TowerType.intelCenter:
        return Icons.radar_rounded;
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
                // The in-game unit is MONEY, deliberately not a dollar sign:
                // real prices in the services sheet are the only $ in the app.
                const Icon(Icons.paid_rounded, size: 12, color: GGColors.good),
                Text('${cost}M',
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

/// Selected-structure panel: condition, repair and upgrade in one place.
class _UpgradePanel extends StatelessWidget {
  const _UpgradePanel({
    required this.selected,
    required this.money,
    required this.onUpgrade,
    required this.onRepair,
  });
  final SelectedStructure selected;
  final int money;
  final VoidCallback onUpgrade;
  final VoidCallback onRepair;

  @override
  Widget build(BuildContext context) {
    final maxed = selected.upgradeCost == null;
    final frac = selected.healthFraction;
    final hpColor = frac > 0.6
        ? GGColors.good
        : frac > 0.3
            ? GGColors.amber
            : GGColors.danger;
    return GGPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(selected.name,
                              overflow: TextOverflow.ellipsis,
                              style: GGText.heading),
                        ),
                        if (selected.isOffline) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: GGColors.danger,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('OFFLINE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                    Text('Tier ${selected.tier + 1} / ${selected.maxTier + 1}',
                        style: GGText.soft),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                height: 7,
                                decoration: BoxDecoration(
                                  color: GGColors.bg,
                                  border:
                                      Border.all(color: GGColors.panelBorder),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: frac.clamp(0.0, 1.0),
                                child: Container(
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: hpColor,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${(frac * 100).round()}%', style: GGText.soft),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (selected.needsRepair)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        money >= selected.repairCost ? onRepair : null,
                    icon: const Icon(Icons.build_rounded, size: 16),
                    label: Text('Repair ${selected.repairCost}M'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GGColors.amber,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              if (selected.needsRepair && !maxed) const SizedBox(width: 8),
              if (!maxed)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: money >= (selected.upgradeCost ?? 0)
                        ? onUpgrade
                        : null,
                    icon: const Icon(Icons.upgrade_rounded, size: 16),
                    label: Text('Upgrade → T${selected.tier + 2} · ${selected.upgradeCost}M'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GGColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              if (maxed && !selected.needsRepair)
                const Expanded(
                  child: Center(
                      child: Text('MAX TIER · OPERATIONAL',
                          style: GGText.soft)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Prompt to fix everything damaged in one tap between raids.
class _RepairAllBar extends StatelessWidget {
  const _RepairAllBar({required this.state, required this.onRepairAll});
  final LevelState state;
  final VoidCallback onRepairAll;

  @override
  Widget build(BuildContext context) {
    final afford = state.money >= state.totalRepairCost;
    return GGPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderColor: GGColors.amber,
      child: Row(
        children: [
          const Icon(Icons.build_circle_rounded,
              color: GGColors.amber, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${state.damagedCount} damaged structure${state.damagedCount == 1 ? '' : 's'}',
              style: GGText.body.copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ElevatedButton(
            onPressed: onRepairAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: afford ? GGColors.amber : GGColors.inkSoft,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text('Repair all ${state.totalRepairCost}M'),
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

/// The WATT exchange: mining is the only source of WATT, so this is where a
/// player decides whether to keep it for permanent perks or burn it to get
/// through a hard stretch.
void _showExchangeSheet(
    BuildContext context, GridGuardGame game, double balance) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: GGColors.panel,
    builder: (ctx) {
      Widget option(double amount, String label) {
        final affordable = balance >= amount && amount > 0;
        return ListTile(
          enabled: affordable,
          leading: const Icon(Icons.swap_horiz_rounded, color: GGColors.amber),
          title: Text(label, style: GGText.body),
          subtitle: Text(
              '${amount.toStringAsFixed(2)} WATT → '
              '${(amount * GridGuardGame.wattToCash).round()}M',
              style: GGText.soft),
          onTap: affordable
              ? () {
                  game.exchangeWatt(amount);
                  Navigator.of(ctx).pop();
                }
              : null,
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  const WattIcon(size: 20),
                  const SizedBox(width: 8),
                  Text('WATT EXCHANGE',
                      style: GGText.body.copyWith(
                          fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const Spacer(),
                  Text('${balance.toStringAsFixed(2)} ⚡',
                      style: GGText.body
                          .copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                  'Only Crypto Mining mints WATT. Rate: 1 WATT = '
                  '${GridGuardGame.wattToCash.round()}M. Spent WATT is gone '
                  'from your perk budget.',
                  style: GGText.soft),
            ),
            option(0.25, 'Cash out 0.25'),
            option(1, 'Cash out 1'),
            option(5, 'Cash out 5'),
            option(double.parse(balance.toStringAsFixed(3)),
                'Cash out everything'),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
