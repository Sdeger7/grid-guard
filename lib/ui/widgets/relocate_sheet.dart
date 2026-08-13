import 'package:flutter/material.dart';

import '../../data/zones.dart';
import '../../game/grid_guard_game.dart';
import '../theme.dart';

/// The relocation offer: sell up and rebuild somewhere harder.
///
/// This is the long game. Everything physical stays behind, everything
/// permanent comes with you, and the new ground rewrites how the site works —
/// so the plan that carried you through a mild meadow is the wrong plan on a
/// storm ridge.
Future<void> showRelocateSheet(BuildContext context, GridGuardGame game) {
  final next = ZoneCatalog.nextAfter(game.zoneIndex);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: GGColors.panel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.moving_rounded, color: GGColors.accent),
                  const SizedBox(width: 8),
                  const Text('RELOCATE THE OPERATION',
                      style: GGText.heading),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                  'Currently at ${game.zone.emoji} ${game.zone.name}, '
                  'day ${game.dayNumber}.',
                  style: GGText.soft),
              const SizedBox(height: 12),
              if (next == null)
                Text(
                    'There is nowhere left to go. You are running the last '
                    'site on the map.',
                    style: GGText.body)
              else ...[
                GGPanel(
                  borderColor: GGColors.accent,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${next.emoji} ${next.name}',
                          style: GGText.body
                              .copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(next.blurb, style: GGText.soft),
                      const SizedBox(height: 10),
                      _Delta(label: 'Solar', scale: next.sunScale),
                      _Delta(label: 'Wind', scale: next.windScale),
                      _Delta(label: 'Power prices', scale: next.priceScale),
                      _Delta(label: 'Contract pay', scale: next.incomeScale),
                      _Delta(
                          label: 'Raid pressure',
                          scale: next.threatScale,
                          higherIsWorse: true),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('WHAT MOVES WITH YOU',
                    style: GGText.soft.copyWith(
                        letterSpacing: 1.2, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                    '• Every ⚡WATT you have mined\n'
                    '• All premium perks you own\n'
                    '• Your records\n'
                    '• Seed capital, scaled up for the new site',
                    style: GGText.soft),
                const SizedBox(height: 10),
                Text('WHAT STAYS BEHIND',
                    style: GGText.soft.copyWith(
                        letterSpacing: 1.2, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                    '• Every panel, turbine, battery, tower and Data Center\n'
                    '• Your cash on hand\n'
                    '• The day count — the new site starts at day 1',
                    style: GGText.soft),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: game.canRelocate
                        ? () {
                            game.relocate();
                            Navigator.of(ctx).pop();
                          }
                        : null,
                    child: Text(game.canRelocate
                        ? 'SELL UP AND MOVE'
                        : 'Hold this site until day ${next.unlockDay}'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// One line of the before/after comparison, phrased as a multiplier.
class _Delta extends StatelessWidget {
  const _Delta({
    required this.label,
    required this.scale,
    this.higherIsWorse = false,
  });

  final String label;
  final double scale;
  final bool higherIsWorse;

  @override
  Widget build(BuildContext context) {
    final better = higherIsWorse ? scale < 1.0 : scale > 1.0;
    final same = (scale - 1.0).abs() < 0.01;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: GGText.soft)),
          Text('${scale.toStringAsFixed(2)}x',
              style: GGText.soft.copyWith(
                fontWeight: FontWeight.w800,
                color: same
                    ? GGColors.inkSoft
                    : better
                        ? GGColors.good
                        : GGColors.danger,
              )),
        ],
      ),
    );
  }
}
