import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/premium_packages.dart';
import '../../services/app_providers.dart';
import '../theme.dart';

/// The COIN store: permanent account perks bought with the coin crypto-mining
/// workloads mint. Every purchase carries into all future runs.
class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: GGColors.panel,
        surfaceTintColor: GGColors.panel,
        elevation: 0,
        title: const Text('PREMIUM', style: GGText.heading),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.currency_bitcoin_rounded,
                    size: 18, color: GGColors.amber),
                const SizedBox(width: 3),
                Text('${profile.coins}', style: GGText.stat),
              ],
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: GGColors.panelBorder),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          GGPanel(
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: GGColors.accent, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Run the Crypto Mining workload to mint COIN. Perks bought '
                    'here apply to every run, permanently.',
                    style: GGText.soft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final p in PremiumCatalog.packages)
            _PackageTile(
              pack: p,
              owned: profile.ownedPackages.contains(p.id),
              affordable: profile.coins >= p.price,
              onBuy: () async {
                final ok = await ref
                    .read(profileProvider.notifier)
                    .buyPackage(p.id, p.price);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? '${p.name} unlocked!'
                      : 'Not enough COIN — mine more with Crypto Mining.'),
                ));
              },
            ),
        ],
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.pack,
    required this.owned,
    required this.affordable,
    required this.onBuy,
  });
  final PremiumPackage pack;
  final bool owned;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GGPanel(
        borderColor: owned ? GGColors.good : GGColors.panelBorder,
        child: Row(
          children: [
            Text(pack.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(pack.name,
                      style:
                          GGText.body.copyWith(fontWeight: FontWeight.w700)),
                  Text(pack.blurb, style: GGText.soft),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (owned)
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: GGColors.good, size: 18),
                  SizedBox(width: 4),
                  Text('OWNED',
                      style: TextStyle(
                          color: GGColors.good,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: affordable ? onBuy : null,
                icon: const Icon(Icons.currency_bitcoin_rounded, size: 16),
                label: Text('${pack.price}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GGColors.amber,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
