import 'package:flutter/material.dart';

import '../../data/cities.dart';
import '../../data/solar.dart';
import '../../game/grid_guard_game.dart';
import '../theme.dart';

/// Where to build.
///
/// Every province here is a real place with its real coordinates and its real
/// solar and wind potential, so the choice is the one an actual developer
/// makes: cheap land under a hard sun far from demand, or expensive ground next
/// to the load centre where power sells for a third more.
Future<void> showCitySheet(
  BuildContext context,
  GridGuardGame game, {
  required VoidCallback onMoved,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: GGColors.panel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (ctx) => _CitySheet(game: game, onMoved: onMoved),
  );
}

class _CitySheet extends StatelessWidget {
  const _CitySheet({required this.game, required this.onMoved});

  final GridGuardGame game;
  final VoidCallback onMoved;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.94,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Row(
              children: [
                const Icon(Icons.map_rounded, color: GGColors.accent),
                const SizedBox(width: 8),
                const Text('SITE LOCATION', style: GGText.heading),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                'Real provinces, real coordinates. The sun over your site is '
                'the sun over that city today — and moving costs the new plot '
                'plus haulage, with half the value of what you leave behind '
                'recovered as salvage.',
                style: GGText.soft),
            const SizedBox(height: 14),
            for (final c in CityCatalog.cities)
              _CityRow(
                city: c,
                current: c.id == game.cityId,
                cost: game.relocationCostTo(c),
                affordable: game.canRelocateTo(c),
                onMove: () {
                  if (game.relocateTo(c)) {
                    Navigator.of(context).pop();
                    onMoved();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _CityRow extends StatelessWidget {
  const _CityRow({
    required this.city,
    required this.current,
    required this.cost,
    required this.affordable,
    required this.onMove,
  });

  final City city;
  final bool current;
  final int cost;
  final bool affordable;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    // Today's real daylight for that province, which is the single most useful
    // number when choosing where to put panels.
    final sun = SolarMath.at(
        latitude: city.latitude, longitude: city.longitude);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GGPanel(
        borderColor: current ? GGColors.accent : GGColors.panelBorder,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(city.name,
                    style: GGText.body.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                if (current)
                  Text('CURRENT SITE',
                      style: GGText.soft.copyWith(
                          color: GGColors.accent,
                          fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('${sun.dayLengthHours.toStringAsFixed(1)} h daylight',
                    style: GGText.soft),
              ],
            ),
            const SizedBox(height: 4),
            Text(city.blurb, style: GGText.soft),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 2,
              children: [
                _Chip('☀️ solar', city.solarIndex),
                _Chip('🌬 wind', city.windIndex),
                _Chip('💱 price', city.priceIndex),
                _Chip('🔥 heat', city.threatIndex, higherIsWorse: true),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                      current
                          ? 'Sun up ${_clock(sun.sunrise)} · '
                              'down ${_clock(sun.sunset)}'
                          : 'Plot ${city.landPrice}M · move for ${cost}M',
                      style: GGText.soft),
                ),
                if (!current)
                  FilledButton(
                    onPressed: affordable ? onMove : null,
                    child: Text(affordable ? 'MOVE' : 'Need ${cost}M'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
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
