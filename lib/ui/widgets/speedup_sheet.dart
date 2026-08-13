import 'package:flutter/material.dart';

import '../../data/speedups.dart';
import '../../game/grid_guard_game.dart';
import '../../services/monetization_service.dart';
import '../theme.dart';

/// The real-money shop, opened from the HUD. The site is a long build by
/// design, so what is sold here is time: banked production, an emergency repair
/// crew, capital. Nothing on this list is out of reach for a player who simply
/// keeps playing.
Future<void> showSpeedupSheet(
  BuildContext context,
  GridGuardGame game,
  MonetizationService store,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: GGColors.panel,
    isScrollControlled: true,
    builder: (ctx) => _SpeedupSheet(game: game, store: store),
  );
}

class _SpeedupSheet extends StatefulWidget {
  const _SpeedupSheet({required this.game, required this.store});

  final GridGuardGame game;
  final MonetizationService store;

  @override
  State<_SpeedupSheet> createState() => _SpeedupSheetState();
}

class _SpeedupSheetState extends State<_SpeedupSheet> {
  String? _pending;

  Future<void> _buy(Speedup item) async {
    setState(() => _pending = item.sku);
    final ok = await widget.store.purchase(item.sku);
    if (!mounted) return;
    setState(() => _pending = null);
    if (!ok) return;
    widget.game.applySpeedup(item);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.name} applied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
            child: Row(
              children: [
                const Icon(Icons.storefront_rounded, color: GGColors.accent),
                const SizedBox(width: 8),
                Text('SITE SERVICES',
                    style: GGText.body.copyWith(
                        fontWeight: FontWeight.w900, letterSpacing: 1)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
                'Building this site takes days on purpose. These buy time, '
                'not power — everything here is reachable by playing.',
                style: GGText.soft),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: SpeedupCatalog.items.length,
              itemBuilder: (_, i) {
                final item = SpeedupCatalog.items[i];
                final busy = _pending == item.sku;
                return ListTile(
                  leading: Text(item.emoji,
                      style: const TextStyle(fontSize: 22)),
                  title: Text(item.name, style: GGText.body),
                  subtitle: Text(item.blurb, style: GGText.soft),
                  trailing: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : FilledButton(
                          onPressed:
                              _pending == null ? () => _buy(item) : null,
                          child: Text(item.priceLabel),
                        ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
