import 'package:flutter/material.dart';

import '../../game/grid_guard_game.dart' show DawnReport;
import '../theme.dart';

/// The morning card: what last night cost, what it paid, today's forecast, and
/// any story traffic. This is the beat that makes a night feel finished and
/// gives the next one a reason.
class DawnPanel extends StatelessWidget {
  const DawnPanel({
    super.key,
    required this.report,
    required this.onClose,
  });

  final DawnReport report;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final beat = report.beat;
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xB30B1220),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: GGPanel(
                borderColor: GGColors.amber,
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wb_twilight_rounded,
                            color: GGColors.amber, size: 22),
                        const SizedBox(width: 8),
                        Text('DAY ${report.day}',
                            style: GGText.body.copyWith(
                                fontWeight: FontWeight.w900, letterSpacing: 1)),
                        const Spacer(),
                        Text('${report.weather.emoji} ${report.weather.name}',
                            style: GGText.body
                                .copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(report.weather.note, style: GGText.soft),
                    if (!report.event.isQuiet) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: GGColors.bg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: GGColors.accentWarm),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${report.event.emoji} ${report.event.name}'
                                .toUpperCase(),
                                style: GGText.soft.copyWith(
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w900,
                                    color: GGColors.accentWarm)),
                            const SizedBox(height: 3),
                            Text(report.event.blurb, style: GGText.soft),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _Line(
                      icon: Icons.shield_moon_rounded,
                      color: GGColors.good,
                      text: 'Night held',
                      value: '+${report.bonus}M',
                    ),
                    if (report.coins > 0) ...[
                      const SizedBox(height: 6),
                      _Line(
                        icon: Icons.paid_rounded, // WATT stat draws its own mark
                        color: GGColors.amber,
                        text: 'Mined overnight',
                        value: report.coins.toStringAsFixed(2),
                      ),
                    ],
                    if (report.damaged > 0) ...[
                      const SizedBox(height: 6),
                      _Line(
                        icon: Icons.build_rounded,
                        color: GGColors.danger,
                        text: 'Needs repair',
                        value: '${report.damaged}',
                      ),
                    ],
                    if (report.forecast.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.radar_rounded,
                              size: 15, color: Color(0xFF7A5CF0)),
                          const SizedBox(width: 6),
                          Text('INTEL FORECAST',
                              style: GGText.soft.copyWith(
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (final f in report.forecast)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              Text(
                                  f.day == report.day
                                      ? 'Tonight'
                                      : 'Night ${f.day}',
                                  style: GGText.soft),
                              const Spacer(),
                              Text(
                                f.raided
                                    ? (f.weight > 1.1
                                        ? 'heavy raid'
                                        : 'raid expected')
                                    : 'quiet',
                                style: GGText.soft.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: f.raided
                                      ? GGColors.danger
                                      : GGColors.good,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Text("TODAY'S ORDERS",
                        style: GGText.soft.copyWith(
                            letterSpacing: 1.2, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    for (final m in report.missions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.radio_button_unchecked_rounded,
                                size: 14, color: GGColors.inkSoft),
                            const SizedBox(width: 8),
                            Expanded(child: Text(m.title, style: GGText.soft)),
                            // Missions pay MONEY; only mining mints WATT.
                            Text('+${m.reward}M',
                                style: GGText.soft.copyWith(
                                    color: GGColors.good,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    if (beat != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: GGColors.bg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: GGColors.panelBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.mail_outline_rounded,
                                    size: 15, color: GGColors.accent),
                                const SizedBox(width: 6),
                                Text(beat.from,
                                    style: GGText.soft.copyWith(
                                        letterSpacing: 1,
                                        fontWeight: FontWeight.w700,
                                        color: GGColors.accent)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(beat.title,
                                style: GGText.body
                                    .copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(beat.body, style: GGText.soft),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onClose,
                        child: const Text('START THE DAY'),
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

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.color,
    required this.text,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String text;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Text(text, style: GGText.soft),
        const Spacer(),
        Text(value,
            style:
                GGText.body.copyWith(fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}
