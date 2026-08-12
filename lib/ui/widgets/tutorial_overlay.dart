import 'package:flutter/material.dart';

import '../../models/level_state.dart';
import '../theme.dart';

/// A short, self-dismissing coach that teaches the loop by reacting to what the
/// player has actually built. Each step clears itself once its goal is met, so
/// nobody reads instructions for something they've already done.
class TutorialOverlay extends StatelessWidget {
  const TutorialOverlay({
    super.key,
    required this.state,
    required this.dismissed,
    required this.onDismiss,
  });

  final LevelState state;

  /// True once the player has dismissed the coach for good.
  final bool dismissed;
  final VoidCallback onDismiss;

  /// The one thing to say right now, or null when there's nothing to teach.
  ({String title, String body, IconData icon})? get _step {
    if (state.generation <= 0) {
      return (
        icon: Icons.solar_power_rounded,
        title: '1 · Build power',
        body: 'Tap the ☀ PV Panel (or 🌬 Wind Turbine) in the tray, then tap '
            'any empty tile. Solar only works by day — wind works at night.',
      );
    }
    if (state.dataCenterCount == 0) {
      return (
        icon: Icons.dns_rounded,
        title: '2 · Earn money',
        body: 'Place a 🖥 Data Center. It burns energy but pays you — money is '
            'what builds and repairs everything else.',
      );
    }
    if (state.security == 0) {
      return (
        icon: Icons.flash_on_rounded,
        title: '3 · Defend the base',
        body: 'Raids fly in from every edge and attack ANY building. Place ⚡ '
            'Shock Transformers and 🛫 Drone Bays around your base.',
      );
    }
    if (state.phase == RunPhase.building) {
      return (
        icon: Icons.play_arrow_rounded,
        title: '4 · Start the shift',
        body: 'Hit START DEFENSE when you\'re ready. Raids escalate forever — '
            'grow, repair, and see how long the grid holds.',
      );
    }
    if (state.damagedCount > 0) {
      return (
        icon: Icons.build_rounded,
        title: 'Repair what\'s hit',
        body: 'Damaged buildings stop working below 30% and are destroyed if '
            'ignored. Use Repair all — it\'s far cheaper than rebuilding.',
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final step = dismissed ? null : _step;
    if (step == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 132, 12, 0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: GGPanel(
            borderColor: GGColors.accent,
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(step.icon, color: GGColors.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(step.title,
                          style: GGText.body
                              .copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(step.body, style: GGText.soft),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: GGColors.inkSoft),
                  tooltip: 'Hide tips',
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
