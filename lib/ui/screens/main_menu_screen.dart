import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/levels.dart';
import '../../services/app_providers.dart';
import '../theme.dart';
import 'game_screen.dart';
import 'guide_screen.dart';
import 'level_select_screen.dart';
import 'premium_screen.dart';
import 'store_screen.dart';

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
              _MenuButton(
                icon: Icons.grid_view_rounded,
                label: 'CAMPAIGN',
                color: GGColors.accent,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const LevelSelectScreen())),
              ),
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
                icon: Icons.menu_book_rounded,
                label: 'HOW IT WORKS',
                color: GGColors.teal,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GuideScreen())),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                icon: Icons.storefront_rounded,
                label: 'MARKET',
                color: GGColors.accent,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StoreScreen())),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt_rounded, size: 16, color: GGColors.mw),
                  const SizedBox(width: 4),
                  Text('${profile.gridCredits} Grid Credits',
                      style: GGText.soft),
                  const SizedBox(width: 16),
                  const Icon(Icons.hexagon_rounded,
                      size: 14, color: GGColors.accentWarm),
                  const SizedBox(width: 4),
                  Text('${profile.energyCores} Cores', style: GGText.soft),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
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
