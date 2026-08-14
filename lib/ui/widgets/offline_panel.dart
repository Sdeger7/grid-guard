import 'package:flutter/material.dart';

import '../../models/base_save.dart';
import '../theme.dart';

/// The "welcome back" report: what the site produced while the app was closed.
/// This is the reason to open the game again tomorrow, so it states plainly how
/// long the site ran and what it banked.
class OfflinePanel extends StatelessWidget {
  const OfflinePanel({
    super.key,
    required this.report,
    required this.onClose,
    this.raids,
    this.onWatchToDouble,
  });

  final OfflineReport report;
  final VoidCallback onClose;

  /// What the automated defences had to deal with alone while you were gone.
  final ({int raids, int damaged, int destroyed, bool blackout})? raids;

  /// Offered only when there is something to double, and always skippable.
  final Future<void> Function()? onWatchToDouble;

  String get _away {
    final mins = report.seconds ~/ 60;
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xCC0B1220),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: GGPanel(
                borderColor: GGColors.good,
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt_rounded,
                            color: GGColors.good, size: 22),
                        const SizedBox(width: 8),
                        Text('The site kept running',
                            style: GGText.body
                                .copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Unattended for $_away. Your Data Centers stayed '
                        'online at reduced output.', style: GGText.soft),
                    const SizedBox(height: 14),
                    _Row(
                      icon: Icons.paid_rounded,
                      color: GGColors.good,
                      label: 'Earned',
                      value: formatCredits(report.money),
                    ),
                    if (report.coins > 0) ...[
                      const SizedBox(height: 8),
                      _Row(
                        icon: Icons.paid_rounded, // WATT stat draws its own mark
                        color: GGColors.amber,
                        label: 'Mined',
                        value: report.coins.toStringAsFixed(2),
                      ),
                    ],
                    if (raids != null && raids!.raids > 0) ...[
                      const SizedBox(height: 14),
                      Text('WHILE YOU WERE GONE',
                          style: GGText.soft.copyWith(
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      _Row(
                        icon: Icons.radar_rounded,
                        color: GGColors.danger,
                        label: 'Raids your defences met alone',
                        value: '${raids!.raids}',
                      ),
                      if (raids!.damaged > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _Row(
                            icon: Icons.build_rounded,
                            color: GGColors.accentWarm,
                            label: 'Damaged',
                            value: '${raids!.damaged}',
                          ),
                        ),
                      if (raids!.destroyed > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _Row(
                            icon: Icons.dangerous_rounded,
                            color: GGColors.danger,
                            label: 'Lost outright',
                            value: '${raids!.destroyed}',
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                          raids!.blackout
                              ? 'The site went dark before dawn. Being here '
                                  'when a window opens is worth more than any '
                                  'upgrade.'
                              : 'Your towers held it. Being present would have '
                                  'held it cheaper.',
                          style: GGText.soft),
                    ],
                    if (report.wasted > 0) ...[
                      const SizedBox(height: 8),
                      _Row(
                        icon: Icons.water_drop_outlined,
                        color: GGColors.danger,
                        label: 'Spilled (storage full)',
                        value: formatCredits(report.wasted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                          'Your site fills up after about '
                          '${report.hoursToFill.toStringAsFixed(1)} hours. '
                          'More BESS storage means more banked while you are '
                          'away.',
                          style: GGText.soft.copyWith(color: GGColors.danger)),
                    ],
                    const SizedBox(height: 18),
                    if (onWatchToDouble != null && report.money > 0) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.play_circle_outline_rounded,
                              size: 18),
                          label: const Text('WATCH TO DOUBLE'),
                          onPressed: () async {
                            await onWatchToDouble!();
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onClose,
                        child: const Text('COLLECT'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(label, style: GGText.soft),
        const Spacer(),
        Text(value,
            style: GGText.body.copyWith(
                fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}
