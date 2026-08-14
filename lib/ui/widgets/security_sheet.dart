import 'package:flutter/material.dart';

import '../../data/insurance.dart';
import '../../data/security.dart';
import '../../game/grid_guard_game.dart';
import '../../services/monetization_service.dart';
import '../theme.dart';

/// Everything that protects the site from what a transformer cannot shoot:
/// the firewall, the bank, standing, and cover.
Future<void> showSecuritySheet(
  BuildContext context,
  GridGuardGame game,
  MonetizationService store,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: GGColors.panel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (_) => _SecuritySheet(game: game, store: store),
  );
}

class _SecuritySheet extends StatefulWidget {
  const _SecuritySheet({required this.game, required this.store});
  final GridGuardGame game;
  final MonetizationService store;

  @override
  State<_SecuritySheet> createState() => _SecuritySheetState();
}

class _SecuritySheetState extends State<_SecuritySheet> {
  String? _buying;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final next = FirewallCatalog.canUpgrade(game.firewallTier)
        ? FirewallCatalog.at(game.firewallTier + 1)
        : null;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Row(
              children: [
                const Icon(Icons.security_rounded, color: GGColors.accent),
                const SizedBox(width: 8),
                const Text('SECURITY', style: GGText.heading),
                const Spacer(),
                Text(Reputation.bandFor(game.reputation),
                    style: GGText.stat.copyWith(
                      color: game.reputation >= 65
                          ? GGColors.good
                          : game.reputation >= 40
                              ? GGColors.accentWarm
                              : GGColors.danger,
                    )),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                'Drones take the hardware. Intruders take the money and the '
                'data, and no transformer stops them.',
                style: GGText.soft),

            // ---- Standing ----
            const SizedBox(height: 16),
            _Header('STANDING'),
            _Line('Reputation',
                '${game.reputation.round()} / 100 · '
                    '${Reputation.bandFor(game.reputation)}'),
            _Line('Contracts pay',
                '${(Reputation.rateMultiplier(game.reputation) * 100).round()}% '
                    'of list'),
            const SizedBox(height: 4),
            Text(
                'A breach costs months of standing in one night, and the best '
                'contracts are not offered to a site nobody trusts. It '
                'recovers slowly, and only while nothing goes wrong.',
                style: GGText.soft),

            // ---- Firewall ----
            const SizedBox(height: 16),
            _Header('FIREWALL'),
            _Line('Installed', game.firewall.name),
            _Line('Stops', '${(game.firewall.resistance * 100).round()}% of '
                'attempts'),
            if (game.firewall.upkeep > 0)
              _Line('Licence',
                  '−${(game.firewall.upkeep * 3600).toStringAsFixed(0)} M/h'),
            const SizedBox(height: 6),
            Text(game.firewall.blurb, style: GGText.soft),
            if (next != null) ...[
              const SizedBox(height: 10),
              GGPanel(
                borderColor: GGColors.accent,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(next.name,
                        style:
                            GGText.body.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(next.blurb, style: GGText.soft),
                    const SizedBox(height: 4),
                    Text(
                        'Stops ${(next.resistance * 100).round()}% · '
                        '−${(next.upkeep * 3600).toStringAsFixed(0)} M/h licence',
                        style: GGText.soft),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: game.money >= next.cost
                            ? () => setState(() => game.upgradeFirewall())
                            : null,
                        child: Text('Install · ${next.cost}M'),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ---- Vault ----
            const SizedBox(height: 18),
            _Header('BANK'),
            _Line('Banked', '${game.vaultMoney.round()}M · '
                '₵${game.vaultWatt.toStringAsFixed(3)}'),
            _Line('Nightly fee',
                '${(GridGuardGame.vaultNightlyFee * 100).round()}% of the '
                    'balance'),
            const SizedBox(height: 4),
            Text(
                'An intruder can only take what is on site. Anything banked is '
                'out of reach — and the bank charges for every night it holds '
                'it, so parking everything there is its own slow loss.',
                style: GGText.soft),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton(
                  onPressed: game.money >= 1000
                      ? () => setState(() => game.depositToVault(1000))
                      : null,
                  child: const Text('Bank 1,000M'),
                ),
                OutlinedButton(
                  onPressed: game.money > 0
                      ? () => setState(
                          () => game.depositToVault(game.money * 0.5))
                      : null,
                  child: const Text('Bank half'),
                ),
                OutlinedButton(
                  onPressed: game.vaultMoney > 0
                      ? () => setState(
                          () => game.withdrawFromVault(game.vaultMoney))
                      : null,
                  child: const Text('Withdraw all'),
                ),
                OutlinedButton(
                  onPressed: game.coinsEarned > 0
                      ? () => setState(
                          () => game.depositWattToVault(game.coinsEarned))
                      : null,
                  child: const Text('Bank all WATT'),
                ),
                OutlinedButton(
                  onPressed: game.vaultWatt > 0
                      ? () => setState(
                          () => game.withdrawWattFromVault(game.vaultWatt))
                      : null,
                  child: const Text('Withdraw WATT'),
                ),
              ],
            ),

            // ---- Wear ----
            const SizedBox(height: 18),
            _Header('PLANT CONDITION'),
            _Line('Average output',
                '${(game.averageCondition * 100).round()}% of nameplate'),
            _Line('Units past their best', '${game.wornCount}'),
            const SizedBox(height: 4),
            Text(
                'Panels lose output every year they stand in the sun, bearings '
                'wear, inverters age. Refurbishment is new glass and new '
                'bearings — not a repair of battle damage, and not free.',
                style: GGText.soft),
            if (game.totalRefurbishCost > 0) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: game.money >= game.totalRefurbishCost
                      ? () => setState(() => game.refurbishAll())
                      : null,
                  child: Text(
                      'Refurbish everything · ${game.totalRefurbishCost}M'),
                ),
              ),
            ],

            // ---- Cover ----
            const SizedBox(height: 18),
            _Header('COVER'),
            Text(
                'A policy never stops anything happening — it refunds part of '
                'what it cost, above an excess you carry yourself. Cover does '
                'not apply in weekly challenges.',
                style: GGText.soft),
            const SizedBox(height: 8),
            for (final p in InsuranceCatalog.policies)
              _PolicyRow(
                policy: p,
                held: game.policies.contains(p.id),
                busy: _buying == p.sku,
                onBuy: () async {
                  setState(() => _buying = p.sku);
                  final ok = await widget.store.purchase(p.sku);
                  if (!mounted) return;
                  setState(() {
                    _buying = null;
                    if (ok) {
                      game.policies = {...game.policies, p.id};
                    }
                  });
                },
              ),

            if (game.breachLog.isNotEmpty) ...[
              const SizedBox(height: 18),
              _Header('INCIDENT LOG'),
              for (final line in game.breachLog.reversed.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('· $line', style: GGText.soft),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.policy,
    required this.held,
    required this.busy,
    required this.onBuy,
  });

  final Policy policy;
  final bool held;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GGPanel(
        borderColor: held ? GGColors.good : GGColors.panelBorder,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(policy.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(policy.name,
                      style:
                          GGText.body.copyWith(fontWeight: FontWeight.w800)),
                  Text(policy.blurb, style: GGText.soft),
                  Text(
                      'Excess ${policy.excess}M · pays '
                      '${(policy.payoutShare * 100).round()}% above it',
                      style: GGText.soft),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (held)
              Text('ACTIVE',
                  style: GGText.soft.copyWith(
                      color: GGColors.good, fontWeight: FontWeight.w800))
            else if (busy)
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              FilledButton(
                  onPressed: onBuy, child: Text(policy.priceLabel)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(title,
            style: GGText.soft.copyWith(
                letterSpacing: 1.2, fontWeight: FontWeight.w900)),
      );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            Expanded(child: Text(label, style: GGText.soft)),
            Text(value,
                style: GGText.soft.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
