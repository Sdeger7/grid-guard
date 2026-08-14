import 'package:flutter/material.dart';

import '../../data/grid_market.dart';
import '../../game/grid_guard_game.dart';
import '../../models/grid_contract.dart';
import '../theme.dart';

/// The power desk: the spot price, the contracts on offer against it, and
/// whatever the site is already committed to.
Future<void> showGridSheet(BuildContext context, GridGuardGame game) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: GGColors.panel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (_) => _GridSheet(game: game),
  );
}

class _GridSheet extends StatefulWidget {
  const _GridSheet({required this.game});
  final GridGuardGame game;

  @override
  State<_GridSheet> createState() => _GridSheetState();
}

class _GridSheetState extends State<_GridSheet> {
  /// Term in in-game hours, and the rate in energy per second.
  double _hours = 2;
  double _rate = 4;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final spot = game.gridPrice;
    final buyPrice = spot * 1.06;
    final sellPrice = spot * GridMarket.sellFraction;
    // A game day is 24 in-game hours, so one hour is dayLength/24 seconds.
    final seconds = _hours * (game.config.dayLength / 24);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.electric_meter_rounded,
                      color: GGColors.accent),
                  const SizedBox(width: 8),
                  const Text('POWER DESK', style: GGText.heading),
                  const Spacer(),
                  Text(GridMarket.bandFor(spot),
                      style: GGText.stat.copyWith(
                        color: spot > 1.2 ? GGColors.danger : GGColors.good,
                      )),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                  'Spot ${spot.toStringAsFixed(2)}M per unit. Power is cheap '
                  'at midday and dear after dark — a contract locks today\'s '
                  'price for its whole term.',
                  style: GGText.soft),
              if (GridMarket.isPeakNow())
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: GGPanel(
                    borderColor: GGColors.accentWarm,
                    padding: const EdgeInsets.all(10),
                    child: Text(
                        '🔥 EVENING PEAK — power is trading at '
                        '${GridMarket.peakMultiplier}x for the next '
                        '${GridMarket.minutesToPeakEdge()} minutes. The best '
                        'sell contracts of the day are right now.',
                        style: GGText.soft.copyWith(
                            fontWeight: FontWeight.w700,
                            color: GGColors.accentWarm)),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                      'The evening peak runs ${GridMarket.peakStartHour}:00 to '
                      '${GridMarket.peakEndHour}:00 your time, when power '
                      'trades at ${GridMarket.peakMultiplier}x. '
                      '${GridMarket.minutesToPeakEdge()} minutes away.',
                      style: GGText.soft),
                ),
              const SizedBox(height: 12),

              // Term and volume.
              _Slider(
                label: 'Term',
                value: _hours,
                min: 1,
                max: 8,
                divisions: 7,
                display: '${_hours.round()} h',
                onChanged: (v) => setState(() => _hours = v),
              ),
              _Slider(
                label: 'Rate',
                value: _rate,
                min: 1,
                max: 12,
                divisions: 11,
                display: '${(_rate * 3600).round()} ⚡/h',
                onChanged: (v) => setState(() => _rate = v),
              ),
              const SizedBox(height: 8),

              _Offer(
                side: GridContractSide.buy,
                price: buyPrice,
                total: buyPrice * _rate * seconds,
                energy: _rate * seconds,
                note: 'Power delivered into your battery. Anything over the '
                    'brim is wasted, so size your storage first.',
                onSign: () {
                  game.signContract(GridContractSide.buy, _rate, seconds);
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 8),
              _Offer(
                side: GridContractSide.sell,
                price: sellPrice,
                total: sellPrice * _rate * seconds,
                energy: _rate * seconds,
                note: 'You must actually deliver. Whatever you cannot supply '
                    'is bought on your behalf at '
                    '${GridGuardGame.imbalancePenalty}x spot — and your '
                    'defence reserve is never touched.',
                onSign: () {
                  game.signContract(GridContractSide.sell, _rate, seconds);
                  Navigator.of(context).pop();
                },
              ),

              if (game.gridContracts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('RUNNING CONTRACTS',
                    style: GGText.soft.copyWith(
                        letterSpacing: 1.2, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                for (final c in game.gridContracts) _Running(contract: c),
              ],

              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: game.gridImportEnabled,
                onChanged: (v) => setState(() => game.gridImportEnabled = v),
                title: Text('Top up at spot', style: GGText.body),
                subtitle: Text(
                    'Buys whatever the market is asking whenever the battery '
                    'falls below 35%. Convenient, and usually the worst price '
                    'you will pay.',
                    style: GGText.soft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 48, child: Text(label, style: GGText.soft)),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(display,
              textAlign: TextAlign.right,
              style: GGText.body.copyWith(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _Offer extends StatelessWidget {
  const _Offer({
    required this.side,
    required this.price,
    required this.total,
    required this.energy,
    required this.note,
    required this.onSign,
  });

  final GridContractSide side;
  final double price;
  final double total;
  final double energy;
  final String note;
  final VoidCallback onSign;

  @override
  Widget build(BuildContext context) {
    final buying = side == GridContractSide.buy;
    final colour = buying ? GGColors.danger : GGColors.good;
    return GGPanel(
      borderColor: colour,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(buying ? Icons.south_west_rounded : Icons.north_east_rounded,
                  size: 18, color: colour),
              const SizedBox(width: 6),
              Text(buying ? 'BUY POWER' : 'SELL POWER',
                  style: GGText.body.copyWith(fontWeight: FontWeight.w900)),
              const Spacer(),
              Text('${price.toStringAsFixed(2)}M / unit',
                  style: GGText.body.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
              '${energy.round()}⚡ total · '
              '${buying ? 'costs' : 'pays'} ${total.round()}M',
              style: GGText.soft.copyWith(color: colour)),
          const SizedBox(height: 4),
          Text(note, style: GGText.soft),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSign,
              style: FilledButton.styleFrom(backgroundColor: colour),
              child: Text(buying ? 'SIGN BUY' : 'SIGN SELL'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Running extends StatelessWidget {
  const _Running({required this.contract});
  final GridContract contract;

  @override
  Widget build(BuildContext context) {
    final buying = contract.side == GridContractSide.buy;
    final colour = buying ? GGColors.danger : GGColors.good;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(buying ? 'Buy' : 'Sell',
                  style: GGText.body.copyWith(
                      fontWeight: FontWeight.w800, color: colour)),
              const SizedBox(width: 6),
              Text(
                  '${(contract.ratePerSecond * 3600).round()}⚡/h @ '
                  '${contract.price.toStringAsFixed(2)}M',
                  style: GGText.soft),
              const Spacer(),
              Text('${contract.secondsLeft.round()}s left',
                  style: GGText.soft),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: contract.progress,
              minHeight: 5,
              backgroundColor: GGColors.panelBorder,
              valueColor: AlwaysStoppedAnimation(colour),
            ),
          ),
          if (contract.shortfall > 0)
            Text('Short ${contract.shortfall.round()}⚡ — paying imbalance',
                style: GGText.soft.copyWith(color: GGColors.danger)),
        ],
      ),
    );
  }
}
