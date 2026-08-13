import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/levels.dart';
import '../../services/app_providers.dart';
import '../theme.dart';
import 'game_screen.dart';
import 'guide_screen.dart';
import 'premium_screen.dart';
import 'skins_screen.dart';

/// Title screen. Minimal engineering-dashboard framing with entry points to the
/// campaign and the store.
class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Row(
                children: [
                  Container(width: 18, height: 40, color: GGColors.accent),
                  const SizedBox(width: 4),
                  Container(width: 18, height: 40, color: GGColors.accentWarm),
                  const SizedBox(width: 12),
                  const Text('GRID\nGUARD',
                      style: TextStyle(
                        fontSize: 40,
                        height: 1.0,
                        fontWeight: FontWeight.w900,
                        color: GGColors.ink,
                        letterSpacing: 1,
                      )),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Defend the grid. Hold the core.',
                  style: GGText.soft),
              const Spacer(),
              _MenuButton(
                icon: Icons.hub_rounded,
                label: 'BASE · SURVIVAL',
                color: GGColors.good,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => GameScreen(config: LevelCatalog.survival))),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              _MenuButton(
                icon: Icons.currency_bitcoin_rounded,
                label: 'PREMIUM',
                color: GGColors.amber,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PremiumScreen())),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                icon: Icons.palette_rounded,
                label: 'WARDROBE',
                color: GGColors.amber,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SkinsScreen())),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                icon: Icons.menu_book_rounded,
                label: 'HOW IT WORKS',
                color: GGColors.teal,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GuideScreen())),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 20),
              // One line, one currency: WATT is the only thing the player
              // actually earns and spends outside a run.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.currency_bitcoin_rounded,
                      size: 16, color: GGColors.amber),
                  const SizedBox(width: 4),
                  Text('${profile.coins} ⚡WATT',
                      style: GGText.soft.copyWith(
                          fontWeight: FontWeight.w800)),
                  if (profile.bestRaid > 0) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.waves_rounded,
                        size: 14, color: GGColors.accentWarm),
                    const SizedBox(width: 4),
                    Text('best raid ${profile.bestRaid}', style: GGText.soft),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Balance changes across versions can leave an old site holding
              // values that no longer make sense, so abandoning it has to be
              // possible — behind a confirmation, since it is permanent.
              TextButton.icon(
                onPressed: () => _confirmAbandon(context, ref),
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: GGColors.inkSoft),
                label: Text('Abandon site and start over',
                    style: GGText.soft),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAbandon(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abandon the site?'),
        content: const Text(
            'Every structure, all your cash and the day count are gone for '
            'good. Mined WATT, perks and cosmetics are kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep playing')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Abandon')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(saveServiceProvider).clearBase();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Site abandoned. Next run starts fresh.')),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
