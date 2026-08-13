import 'package:flutter/material.dart';

import '../../data/streak.dart';
import '../theme.dart';

/// The daily check-in card.
///
/// Shown once per day, on the first launch of that day. It states plainly what
/// today pays, what the next milestone is, and what a missed day costs — the
/// last part being the reason anyone comes back tomorrow.
class StreakPanel extends StatelessWidget {
  const StreakPanel({
    super.key,
    required this.day,
    required this.onClaim,
  });

  final int day;
  final VoidCallback onClaim;

  int get _nextMilestone {
    for (final m in [7, 14, 30]) {
      if (day < m) return m;
    }
    return 30;
  }

  @override
  Widget build(BuildContext context) {
    final reward = StreakCalendar.rewardFor(day);

    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xCC0B1220),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: GGPanel(
                borderColor: GGColors.accent,
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded,
                            color: GGColors.accentWarm, size: 22),
                        const SizedBox(width: 8),
                        Text('DAY $day STREAK',
                            style: GGText.body.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // A week of dots reads faster than a number, and shows the
                    // run the player is protecting.
                    Row(
                      children: [
                        for (var i = 1; i <= 7; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i <= ((day - 1) % 7) + 1
                                    ? GGColors.accentWarm
                                    : GGColors.panelBorder,
                              ),
                              child: Center(
                                child: Text('$i',
                                    style: GGText.soft.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: i <= ((day - 1) % 7) + 1
                                          ? Colors.white
                                          : GGColors.inkSoft,
                                    )),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Text('Today pays', style: GGText.soft),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.paid_rounded,
                            size: 18, color: GGColors.good),
                        const SizedBox(width: 6),
                        Text('${reward.cash}M',
                            style: GGText.body.copyWith(
                                fontWeight: FontWeight.w900,
                                color: GGColors.good)),
                        if (reward.watt > 0) ...[
                          const SizedBox(width: 14),
                          const WattIcon(size: 16),
                          const SizedBox(width: 4),
                          Text('${reward.watt}',
                              style: GGText.body.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: GGColors.amber)),
                        ],
                      ],
                    ),
                    if (reward.label != null) ...[
                      const SizedBox(height: 6),
                      Text(reward.label!,
                          style: GGText.soft.copyWith(
                              color: GGColors.accent,
                              fontWeight: FontWeight.w700)),
                    ],
                    const SizedBox(height: 12),
                    Text(
                        'Day $_nextMilestone is the next milestone. Miss a day '
                        'and the streak starts again at one.',
                        style: GGText.soft),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onClaim,
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
