import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/app_providers.dart';
import '../screens/guide_screen.dart';
import '../screens/premium_screen.dart';
import '../screens/skins_screen.dart';
import '../theme.dart';

/// Everything that is not the site itself, one tap from inside it.
///
/// There is no main menu: the site is always running, so the wardrobe, the
/// perk store, the manual and the services sheet open over it and hand the
/// player straight back when they close.
Future<void> showSiteMenu(
  BuildContext context,
  WidgetRef ref, {
  required VoidCallback onOpenServices,
  required VoidCallback onOpenReport,
  required VoidCallback onAbandon,
  required VoidCallback onOpenChallenge,
  required VoidCallback onOpenCities,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: GGColors.panel,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (ctx) {
      final profile = ref.read(profileProvider);

      Widget entry({
        required IconData icon,
        required Color colour,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
        return ListTile(
          leading: Icon(icon, color: colour),
          title: Text(title, style: GGText.body),
          subtitle: Text(subtitle, style: GGText.soft),
          onTap: () {
            Navigator.of(ctx).pop();
            onTap();
          },
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  const Text('SITE', style: GGText.heading),
                  const Spacer(),
                  const WattIcon(size: 16),
                  const SizedBox(width: 4),
                  Text('${profile.coins}',
                      style: GGText.body.copyWith(
                          fontWeight: FontWeight.w800,
                          color: GGColors.amber)),
                ],
              ),
            ),
            entry(
              icon: Icons.map_rounded,
              colour: GGColors.accent,
              title: 'Land',
              subtitle: 'Buy or rent plots worldwide, wheel power between them',
              onTap: onOpenCities,
            ),
            entry(
              icon: Icons.emoji_events_rounded,
              colour: GGColors.amber,
              title: 'Weekly challenge',
              subtitle: 'Same seed for everyone — a score worth comparing',
              onTap: onOpenChallenge,
            ),
            entry(
              icon: Icons.receipt_long_rounded,
              colour: GGColors.good,
              title: 'Site report',
              subtitle: 'Every M and ⚡ in and out, line by line',
              onTap: onOpenReport,
            ),
            entry(
              icon: Icons.palette_rounded,
              colour: GGColors.amber,
              title: 'Wardrobe',
              subtitle: 'Skins for drones, structures and terrain',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SkinsScreen())),
            ),
            entry(
              icon: Icons.workspace_premium_rounded,
              colour: GGColors.amber,
              title: 'Perks',
              subtitle: 'Permanent upgrades bought with WATT',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PremiumScreen())),
            ),
            entry(
              icon: Icons.storefront_rounded,
              colour: GGColors.accent,
              title: 'Services',
              subtitle: 'Buy time: banked shifts, repair crews, capital',
              onTap: onOpenServices,
            ),
            entry(
              icon: Icons.menu_book_rounded,
              colour: GGColors.teal,
              title: 'How the site works',
              subtitle: 'Energy, contracts, the market, raids, currencies',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GuideScreen())),
            ),
            const Divider(height: 20),
            entry(
              icon: Icons.delete_outline_rounded,
              colour: GGColors.danger,
              title: 'Abandon site',
              subtitle: 'Start over. WATT, perks and skins are kept',
              onTap: () => _confirmAbandon(context, ref, onAbandon),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

Future<void> _confirmAbandon(
    BuildContext context, WidgetRef ref, VoidCallback onAbandon) async {
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
  // Clear the running site first: the autosave would otherwise write the old
  // one straight back over the deleted file.
  onAbandon();
  await ref.read(saveServiceProvider).clearBase();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Site abandoned. Fresh ground.')),
  );
}
