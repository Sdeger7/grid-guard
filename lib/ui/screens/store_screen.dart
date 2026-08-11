import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/player_profile.dart';
import '../../models/tower_type.dart';
import '../../services/app_providers.dart';
import '../../services/monetization_service.dart';
import '../theme.dart';

/// A store item priced in either soft (Grid Credits) or hard (Energy Cores)
/// currency, or a real-money IAP.
enum _Currency { gridCredits, energyCores, iap }

class _StoreItem {
  const _StoreItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.currency,
    required this.price,
    this.sku,
    this.unlockTower,
  });
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final _Currency currency;
  final int price;
  final String? sku;
  final TowerType? unlockTower;
}

const _catalog = <_StoreItem>[
  _StoreItem(
    id: 'skin_pv_solaris',
    title: 'PV Skin · Solaris',
    subtitle: 'Cosmetic panel finish',
    icon: Icons.solar_power_rounded,
    currency: _Currency.gridCredits,
    price: 120,
  ),
  _StoreItem(
    id: 'skin_shock_arc',
    title: 'Transformer Skin · Arc',
    subtitle: 'Cosmetic tower finish',
    icon: Icons.flash_on_rounded,
    currency: _Currency.gridCredits,
    price: 200,
  ),
  _StoreItem(
    id: 'skin_barrier_titan',
    title: 'Barrier Skin · Titan',
    subtitle: 'Cosmetic barrier finish',
    icon: Icons.content_cut_rounded,
    currency: _Currency.energyCores,
    price: 8,
  ),
  _StoreItem(
    id: 'starter_pack',
    title: 'Starter Pack',
    subtitle: '500 Grid Credits + 20 Energy Cores',
    icon: Icons.card_giftcard_rounded,
    currency: _Currency.iap,
    price: 0,
    sku: Skus.starterPack,
  ),
];

/// Store mockup: cosmetic skins & unlocks priced in Grid Credits / Energy
/// Cores, plus a Starter Pack IAP tile wired to the (mock) MonetizationService.
/// No real purchase flow — the interface is what matters here.
class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: GGColors.panel,
        surfaceTintColor: GGColors.panel,
        elevation: 0,
        title: const Text('MARKET', style: GGText.heading),
        actions: [
          _Balance(
              icon: Icons.bolt_rounded,
              color: GGColors.mw,
              value: profile.gridCredits),
          _Balance(
              icon: Icons.hexagon_rounded,
              color: GGColors.accentWarm,
              value: profile.energyCores),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: GGColors.panelBorder),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.92,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _catalog.length,
        itemBuilder: (context, i) =>
            _StoreCard(item: _catalog[i], profile: profile),
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.icon, required this.color, required this.value});
  final IconData icon;
  final Color color;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 2),
          Text('$value', style: GGText.stat),
        ],
      ),
    );
  }
}

class _StoreCard extends ConsumerWidget {
  const _StoreCard({required this.item, required this.profile});
  final _StoreItem item;
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owned = item.currency == _Currency.iap
        ? ref
            .read(monetizationServiceProvider)
            .isProductPurchased(item.sku ?? '')
        : profile.ownedSkins.contains(item.id);

    return GGPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 30, color: GGColors.accent),
          const SizedBox(height: 8),
          Text(item.title, style: GGText.body.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(item.subtitle, style: GGText.soft, maxLines: 2),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: owned
                ? OutlinedButton(
                    onPressed: null,
                    child: Text(item.currency == _Currency.iap
                        ? 'Purchased'
                        : 'Owned'),
                  )
                : ElevatedButton(
                    onPressed: () => _buy(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: item.currency == _Currency.iap
                          ? GGColors.accentWarm
                          : GGColors.accent,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_priceLabel()),
                  ),
          ),
        ],
      ),
    );
  }

  String _priceLabel() {
    switch (item.currency) {
      case _Currency.gridCredits:
        return '${item.price} Credits';
      case _Currency.energyCores:
        return '${item.price} Cores';
      case _Currency.iap:
        return 'Buy · \$4.99';
    }
  }

  Future<void> _buy(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(profileProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    if (item.currency == _Currency.iap) {
      final ok =
          await ref.read(monetizationServiceProvider).purchase(item.sku!);
      if (ok) {
        await notifier.markPurchased(item.sku!);
        // Starter pack grants (mock).
        await notifier.awardBonusCredits(500);
        messenger.showSnackBar(
            const SnackBar(content: Text('Starter Pack unlocked!')));
      }
      return;
    }

    if (item.currency == _Currency.gridCredits) {
      final ok = await notifier.spendGridCredits(item.price);
      if (!ok) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Not enough Grid Credits.')));
        return;
      }
    } else {
      // Energy Cores — nothing grants them yet, so this will generally fail.
      messenger.showSnackBar(
          const SnackBar(content: Text('Not enough Energy Cores.')));
      return;
    }

    await notifier.grantSkin(item.id);
    if (item.unlockTower != null) {
      await notifier.unlockTower(item.unlockTower!);
    }
    messenger
        .showSnackBar(SnackBar(content: Text('${item.title} unlocked!')));
  }
}
