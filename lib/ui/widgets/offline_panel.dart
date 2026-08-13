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
  });

  final OfflineReport report;
  final VoidCallback onClose;

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
                      icon: Icons.attach_money_rounded,
                      color: GGColors.good,
                      label: 'Earned',
                      value: '\$${report.money}',
                    ),
                    if (report.coins > 0) ...[
                      const SizedBox(height: 8),
                      _Row(
                        icon: Icons.currency_bitcoin_rounded,
                        color: GGColors.amber,
                        label: 'Mined',
                        value: report.coins.toStringAsFixed(2),
                      ),
                    ],
                    const SizedBox(height: 18),
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
