import 'package:flutter/material.dart';

import '../../data/cities.dart';
import '../../data/solar.dart';
import '../../game/grid_guard_game.dart';
import '../../models/land_holding.dart';
import '../theme.dart';

/// The land book: everywhere in the world you could build, and everywhere you
/// already hold.
///
/// The choice is the one a real developer makes. Cheap desert under a hard sun,
/// far from anyone who wants the power; or expensive ground beside a city that
/// pays a third more for it. Rent to start moving today, or buy and stop paying
/// forever. And once you hold more than one plot, the sun is always up
/// somewhere — for the price of moving the power there.
Future<void> showCitySheet(
  BuildContext context,
  GridGuardGame game, {
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: GGColors.panel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (ctx) => _CitySheet(game: game, onChanged: onChanged),
  );
}

class _CitySheet extends StatefulWidget {
  const _CitySheet({required this.game, required this.onChanged});

  final GridGuardGame game;
  final VoidCallback onChanged;

  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Row(
              children: [
                const Icon(Icons.public_rounded, color: GGColors.accent),
                const SizedBox(width: 8),
                const Text('LAND', style: GGText.heading),
                const Spacer(),
                Text('${game.money.floor()}M', style: GGText.soft),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                'Real places, real coordinates, real sun. Rent to start today '
                'and keep paying, or buy and stop. Plots you are not standing '
                'on still earn — and you can wheel their power to your site, '
                'minus what the distance costs.',
                style: GGText.soft),

            if (game.holdings.length > 1) ...[
              const SizedBox(height: 16),
              Text('YOUR PORTFOLIO',
                  style: GGText.soft.copyWith(
                      letterSpacing: 1.2, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final h in game.holdings)
                if (h.cityId != game.cityId) _Portfolio(
                  game: game,
                  holding: h,
                  onChanged: () {
                    widget.onChanged();
                    setState(() {});
                  },
                ),
            ],

            for (final region in CityRegion.values) ...[
              const SizedBox(height: 18),
              Text(region.label.toUpperCase(),
                  style: GGText.soft.copyWith(
                      letterSpacing: 1.2, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final c in CityCatalog.inRegion(region))
                _CityRow(
                  game: game,
                  city: c,
                  onChanged: () {
                    widget.onChanged();
                    setState(() {});
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A plot you hold but are not standing on: what it earns, what it costs, and
/// the two things you can do with it.
class _Portfolio extends StatelessWidget {
  const _Portfolio({
    required this.game,
    required this.holding,
    required this.onChanged,
  });

  final GridGuardGame game;
  final LandHolding holding;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = CityCatalog.byId(holding.cityId);
    final km = c.distanceTo(game.city);
    final efficiency = GridGuardGame.transmissionEfficiency(km);
    final fee = GridGuardGame.wheelingFee(km);
    final sun = SolarMath.at(latitude: c.latitude, longitude: c.longitude);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GGPanel(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${c.name}, ${c.country}',
                    style: GGText.body.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Text(holding.tenure == Tenure.owned ? 'FREEHOLD' : 'LEASED',
                    style: GGText.soft.copyWith(
                        fontWeight: FontWeight.w800,
                        color: holding.tenure == Tenure.owned
                            ? GGColors.good
                            : GGColors.accentWarm)),
                const Spacer(),
                Text(sun.isDay ? '☀️ day' : '🌙 night', style: GGText.soft),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                'Invested ${holding.development}M · '
                '${(km / 1000).toStringAsFixed(1)}k km away · '
                'line delivers ${(efficiency * 100).round()}%',
                style: GGText.soft),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton(
                  onPressed: game.money >= 500
                      ? () {
                          game.developHolding(holding.cityId, 500);
                          onChanged();
                        }
                      : null,
                  child: const Text('Invest 500M'),
                ),
                OutlinedButton(
                  onPressed: game.money >= fee
                      ? () {
                          game.importFromHolding(holding.cityId, 60);
                          onChanged();
                        }
                      : null,
                  child: Text('Wheel 60⚡ · ${fee}M'),
                ),
                OutlinedButton(
                  onPressed: game.money >=
                          CityCatalog.haulageBetween(game.city, c)
                      ? () {
                          game.moveOperationTo(c);
                          onChanged();
                        }
                      : null,
                  child: Text(
                      'Move here · ${CityCatalog.haulageBetween(game.city, c)}M'),
                ),
                TextButton(
                  onPressed: () {
                    game.releaseLand(holding.cityId);
                    onChanged();
                  },
                  child: Text(
                      holding.tenure == Tenure.owned ? 'Sell plot' : 'End lease',
                      style: GGText.soft.copyWith(color: GGColors.danger)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CityRow extends StatelessWidget {
  const _CityRow({
    required this.game,
    required this.city,
    required this.onChanged,
  });

  final GridGuardGame game;
  final City city;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final held = game.holds(city.id);
    final here = city.id == game.cityId;
    final sun = SolarMath.at(
        latitude: city.latitude, longitude: city.longitude);
    final locked = city.premium && !game.premiumUnlocked.contains(city.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: locked ? 0.7 : 1,
        child: GGPanel(
          borderColor: here
              ? GGColors.accent
              : city.premium
                  ? GGColors.amber
                  : GGColors.panelBorder,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                        '${city.name}, ${city.country}'
                        '${city.premium ? '  ★' : ''}',
                        style: GGText.body
                            .copyWith(fontWeight: FontWeight.w900)),
                  ),
                  Text(
                      '${sun.dayLengthHours.toStringAsFixed(1)}h · '
                      '${sun.isDay ? 'day' : 'night'}',
                      style: GGText.soft),
                ],
              ),
              if (here)
                Text('YOUR SITE',
                    style: GGText.soft.copyWith(
                        color: GGColors.accent,
                        fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(city.blurb, style: GGText.soft),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 2,
                children: [
                  _Chip('☀️', city.solarIndex),
                  _Chip('🌬', city.windIndex),
                  _Chip('💱', city.priceIndex),
                  _Chip('🔥', city.threatIndex, higherIsWorse: true),
                ],
              ),
              const SizedBox(height: 8),
              if (locked)
                Text(
                    'Premium ground — the best resource measured anywhere. '
                    'Unlocked separately.',
                    style: GGText.soft.copyWith(
                        color: GGColors.amber,
                        fontWeight: FontWeight.w700))
              else if (!held)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: game.money >= city.rentPerDay * 7
                            ? () {
                                game.acquireLand(city, Tenure.rented);
                                onChanged();
                              }
                            : null,
                        child: Text('Rent · ${city.rentPerDay}M/day'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: game.money >= city.landPrice
                            ? () {
                                game.acquireLand(city, Tenure.owned);
                                onChanged();
                              }
                            : null,
                        child: Text('Buy · ${city.landPrice}M'),
                      ),
                    ),
                  ],
                )
              else if (!here)
                Text('Held — manage it in your portfolio above',
                    style: GGText.soft),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.value, {this.higherIsWorse = false});
  final String label;
  final double value;
  final bool higherIsWorse;

  @override
  Widget build(BuildContext context) {
    final better = higherIsWorse ? value < 1.0 : value > 1.0;
    return Text('$label ${value.toStringAsFixed(2)}x',
        style: GGText.soft.copyWith(
          fontWeight: FontWeight.w700,
          color: (value - 1).abs() < 0.03
              ? GGColors.inkSoft
              : better
                  ? GGColors.good
                  : GGColors.danger,
        ));
  }
}
