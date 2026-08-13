import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/skins.dart';
import '../../services/app_providers.dart';
import '../theme.dart';

/// The wardrobe: cosmetic sets bought with WATT and worn per slot.
///
/// Cosmetics are the honest sink for a closed currency — they give mining a
/// reason to exist without ever selling power, so nobody who skips them is
/// playing a worse game.
class SkinsScreen extends ConsumerWidget {
  const SkinsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wardrobe'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Text('${profile.coins} ⚡WTT',
                  style: GGText.body.copyWith(
                      fontWeight: FontWeight.w800, color: GGColors.amber)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
        children: [
          Text(
              'Paint only. Nothing here changes a single number — WATT buys '
              'looks, never power.',
              style: GGText.soft),
          const SizedBox(height: 14),
          for (final slot in SkinSlot.values) ...[
            Text(_slotName(slot).toUpperCase(),
                style: GGText.soft.copyWith(
                    letterSpacing: 1.2, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (final skin in SkinCatalog.forSlot(slot))
              _SkinRow(
                skin: skin,
                owned: skin.free || profile.ownedSkins.contains(skin.id),
                equipped: (profile.equippedSkins[slot.name] ??
                        SkinCatalog.defaultFor(slot).id) ==
                    skin.id,
                affordable: profile.coins >= skin.price,
                onBuy: () => ref
                    .read(profileProvider.notifier)
                    .buySkin(skin.id, skin.price),
                onEquip: () => ref
                    .read(profileProvider.notifier)
                    .equipSkin(slot.name, skin.id),
              ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }

  String _slotName(SkinSlot slot) {
    switch (slot) {
      case SkinSlot.drone:
        return 'Interceptor drones';
      case SkinSlot.structure:
        return 'Structures';
      case SkinSlot.terrain:
        return 'Terrain';
    }
  }
}

class _SkinRow extends StatelessWidget {
  const _SkinRow({
    required this.skin,
    required this.owned,
    required this.equipped,
    required this.affordable,
    required this.onBuy,
    required this.onEquip,
  });

  final Skin skin;
  final bool owned;
  final bool equipped;
  final bool affordable;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GGPanel(
        borderColor: equipped ? GGColors.accent : GGColors.panelBorder,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // A three-swatch chip is a truer preview than an icon: it is
            // literally the palette the game will paint with.
            _Swatches(skin: skin),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${skin.emoji} ${skin.name}',
                      style:
                          GGText.body.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(skin.blurb, style: GGText.soft),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (equipped)
              Text('WORN',
                  style: GGText.soft.copyWith(
                      color: GGColors.accent, fontWeight: FontWeight.w800))
            else if (owned)
              OutlinedButton(onPressed: onEquip, child: const Text('Wear'))
            else
              FilledButton(
                onPressed: affordable ? onBuy : null,
                child: Text('${skin.price} ⚡'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.skin});
  final Skin skin;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Column(
        children: [
          Expanded(
              child: Container(
                  decoration: BoxDecoration(
                      color: skin.primary,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4))))),
          Expanded(child: Container(color: skin.secondary)),
          Expanded(
              child: Container(
                  decoration: BoxDecoration(
                      color: skin.accent,
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(4))))),
        ],
      ),
    );
  }
}
