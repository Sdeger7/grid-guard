import 'package:flutter/material.dart';

import '../../data/watt_supply.dart';
import '../../game/grid_guard_game.dart';
import '../../models/tower_type.dart';
import '../theme.dart';

/// The site report: where every unit of money and energy actually goes.
///
/// The economy has enough moving parts — contracts, upkeep, the market, mining,
/// per-machine workloads — that a player cannot reason about it from the meters
/// alone. This states the whole balance sheet in one place, per line item, at
/// the rates running right now.
Future<void> showReportSheet(BuildContext context, GridGuardGame game) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: GGColors.panel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (_) => _ReportSheet(game: game),
  );
}

class _ReportSheet extends StatelessWidget {
  const _ReportSheet({required this.game});
  final GridGuardGame game;

  @override
  Widget build(BuildContext context) {
    // Money in.
    // What the machines are actually earning, not their nameplate.
    final income = game.dcIncome * game.dcLoadFraction;
    final exportRate = game.perks.gridExportRate > 0
        ? game.gridSellPrice * game.perks.gridExportRate
        : 0.0;

    // Money out.
    final upkeep = game.operatingCost;
    final intel = game.intelUpkeep;
    final contractsIn = game.gridContracts
        .where((c) => c.side.name == 'sell')
        .fold(0.0, (s, c) => s + c.price * c.ratePerSecond);
    final contractsOut = game.gridContracts
        .where((c) => c.side.name == 'buy')
        .fold(0.0, (s, c) => s + c.price * c.ratePerSecond);

    final netMoney = income + exportRate + contractsIn - upkeep - contractsOut;

    // Energy.
    final solar = game.effectivePvOutput;
    final wind = game.effectiveWindOutput;
    final generator = game.perks.chargeRateBonus;
    final dcDraw = game.dcHalted ? 0.0 : game.dcDraw;
    final intelDraw =
        GridGuardGame.intelEnergyPerCenter * game.intelCenters.length;
    final lighting = game.lightingLoad;
    final netEnergy = solar + wind + generator - dcDraw - intelDraw - lighting;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: GGColors.accent),
                const SizedBox(width: 8),
                const Text('SITE REPORT', style: GGText.heading),
                const Spacer(),
                Text('day ${game.dayNumber} · ${game.city.name}',
                    style: GGText.soft),
              ],
            ),
            const SizedBox(height: 14),

            _Header('MONEY', trailing: _rate(netMoney * 3600, 'M/h')),
            if (game.dcLoadFraction < 0.98 && game.dataCenters.isNotEmpty)
              _Line(
                  'Machines running at '
                      '${(game.dcLoadFraction * 100).round()}% of demand',
                  'income scaled to match'),
            _Line('Data Center contracts',
                '+${(income * 3600).toStringAsFixed(0)} M/h', good: true),
            if (exportRate > 0)
              _Line('Grid export (per surplus unit)',
                  '+${(exportRate * 3600).toStringAsFixed(0)} M/h', good: true),
            if (contractsIn > 0)
              _Line('Sell contracts',
                  '+${(contractsIn * 3600).toStringAsFixed(0)} M/h', good: true),
            _Line('Upkeep on everything built',
                '−${(upkeep * 3600).toStringAsFixed(0)} M/h'),
            if (intel > 0)
              _Line('Intel Center running costs',
                  '−${(intel * 3600).toStringAsFixed(0)} M/h'),
            if (contractsOut > 0)
              _Line('Buy contracts',
                  '−${(contractsOut * 3600).toStringAsFixed(0)} M/h'),
            const SizedBox(height: 6),
            _Line('Balance', _rate(netMoney * 3600, 'M/h'),
                bold: true, good: netMoney >= 0),

            const SizedBox(height: 18),
            _Header('ENERGY', trailing: _rate(netEnergy * 3600, '⚡/h')),
            _Line('Solar (sun ${(game.sunFactor * 100).round()}%, '
                '${game.weather.name.toLowerCase()})',
                '+${(solar * 3600).toStringAsFixed(0)} ⚡/h', good: true),
            _Line('Wind (${(game.windFactor * 100).round()}%)',
                '+${(wind * 3600).toStringAsFixed(0)} ⚡/h', good: true),
            if (generator > 0)
              _Line('Generator',
                  '+${(generator * 3600).toStringAsFixed(0)} ⚡/h',
                  good: true),
            _Line('Data Centers',
                '−${(dcDraw * 3600).toStringAsFixed(0)} ⚡/h'),
            if (intelDraw > 0)
              _Line('Intel Centers',
                  '−${(intelDraw * 3600).toStringAsFixed(0)} ⚡/h'),
            if (lighting > 0)
              _Line('Site lighting (${game.structures.length} buildings)',
                  '−${(lighting * 3600).toStringAsFixed(0)} ⚡/h'),
            _Line('Defences', 'per shot, from the reserve'),
            const SizedBox(height: 6),
            _Line('Balance', _rate(netEnergy * 3600, '⚡/h'),
                bold: true, good: netEnergy >= 0),
            _Line('Battery',
                '${game.energy.toStringAsFixed(0)} / '
                '${game.energyCapacity.toStringAsFixed(0)}  '
                '(${game.defenceReserve.toStringAsFixed(0)} held for defence)'),

            const SizedBox(height: 18),
            _Header('WATT',
                trailing: '${(game.coinRate * 3600).toStringAsFixed(3)} /h'),
            _Line('Mining machines',
                '${game.dataCenters.where((d) => game.workloadOf(d).minesCoins).length}'
                ' of ${game.dataCenters.length}'),
            _Line('Balance', '₵${game.coinsEarned.toStringAsFixed(3)}',
                bold: true),
            _Line(
                'Network difficulty',
                '${WattSupply.difficultyAt().toStringAsFixed(1)}× launch rate'),
            _Line(
                'Supply issued',
                '${(WattSupply.issuedFraction() * 100).toStringAsFixed(1)}% of '
                    '${WattSupply.maxSupply.toInt()}'),

            const SizedBox(height: 18),
            _Header('CONDITION',
                trailing:
                    '${(game.averageCondition * 100).round()}% of nameplate'),
            _Line('Units past their best', '${game.wornCount}'),
            if (game.totalRefurbishCost > 0)
              _Line('Refurbish everything', '${game.totalRefurbishCost}M'),
            const SizedBox(height: 4),

            const SizedBox(height: 14),
            _Header('WHAT IS BUILT'),
            for (final row in _inventory()) _Line(row.$1, row.$2),

            const SizedBox(height: 18),
            _Header('DATA CENTERS'),
            for (final dc in game.dataCenters)
              _Line(
                'DC ${dc.dcIndex + 1} · T${dc.tier + 1} · '
                    '${game.workloadOf(dc).name}',
                game.workloadOf(dc).minesCoins
                    ? 'mines WATT'
                    : '+${(game.workloadOf(dc).income * 3600).toStringAsFixed(0)} M/h',
              ),
            if (game.dataCenters.isEmpty)
              _Line('None built', 'no income at all'),
          ],
        ),
      ),
    );
  }

  String _rate(double v, String unit) =>
      '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)} $unit';

  /// One line per structure type: how many, and what they cost to own.
  List<(String, String)> _inventory() {
    final counts = <TowerType, int>{};
    final upkeep = <TowerType, double>{};
    for (final s in game.structures) {
      counts.update(s.spec.type, (v) => v + 1, ifAbsent: () => 1);
      upkeep.update(
          s.spec.type,
          (v) => v + s.currentTier.cost * GridGuardGame.upkeepRate,
          ifAbsent: () => s.currentTier.cost * GridGuardGame.upkeepRate);
    }
    final out = <(String, String)>[];
    counts.forEach((type, n) {
      final spec = TowerCatalogNames.of(type);
      out.add((
        '$spec ×$n',
        '−${(upkeep[type]! * 3600).toStringAsFixed(0)} M/h upkeep',
      ));
    });
    if (out.isEmpty) out.add(('Nothing built yet', ''));
    return out;
  }
}

/// Short display names, kept here so the report does not need the full catalog.
class TowerCatalogNames {
  static String of(TowerType type) {
    switch (type) {
      case TowerType.pvPanel:
        return 'PV panels';
      case TowerType.windTurbine:
        return 'Wind turbines';
      case TowerType.bess:
        return 'BESS units';
      case TowerType.dataCenter:
        return 'Data Centers';
      case TowerType.droneBay:
        return 'Drone bays';
      case TowerType.scissorBarrier:
        return 'Barriers';
      case TowerType.shockTransformer:
        return 'Transformers';
      case TowerType.intelCenter:
        return 'Intel Centers';
    }
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, {this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(title,
              style: GGText.soft.copyWith(
                  letterSpacing: 1.2, fontWeight: FontWeight.w900)),
          const Spacer(),
          if (trailing != null)
            Text(trailing!,
                style: GGText.body.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.good, this.bold = false});
  final String label;
  final String value;
  final bool? good;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final colour = good == null
        ? GGColors.ink
        : good!
            ? GGColors.good
            : GGColors.danger;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: GGText.soft)),
          const SizedBox(width: 10),
          Text(value,
              style: GGText.soft.copyWith(
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                color: good == null && !bold ? GGColors.inkSoft : colour,
              )),
        ],
      ),
    );
  }
}
