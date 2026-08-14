import 'package:flutter/material.dart';

import '../../data/staff.dart';
import '../../game/grid_guard_game.dart';
import '../theme.dart';

/// The crew: three roles that quietly get better at their job the longer the
/// site stays open. No hiring, no wages — just levels, and the bonus each one
/// carries into its part of the business.
Future<void> showStaffSheet(BuildContext context, GridGuardGame game) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: GGColors.panel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (_) => _StaffSheet(game: game),
  );
}

class _StaffSheet extends StatelessWidget {
  const _StaffSheet({required this.game});
  final GridGuardGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Row(
              children: [
                const Icon(Icons.groups_rounded, color: GGColors.accent),
                const SizedBox(width: 8),
                const Text('TEAM', style: GGText.heading),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                'They level up on their own the longer the site stays open — '
                'nothing to buy, nothing to manage.',
                style: GGText.soft),
            const SizedBox(height: 16),
            for (final role in StaffRole.values)
              _StaffCard(member: game.staff.of(role)),
          ],
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.member});
  final StaffMember member;

  String _bonusLine() {
    switch (member.role) {
      case StaffRole.engineer:
        final upkeepOff = ((1 - member.upkeepMultiplier) * 100).round();
        final outputUp = ((member.outputMultiplier - 1) * 100).round();
        return '−$upkeepOff% upkeep · +$outputUp% panel & turbine output';
      case StaffRole.security:
        final resist = (member.resistanceBonus * 100).round();
        final freqDown =
            ((1 - member.intrusionFrequencyMultiplier) * 100).round();
        return '+$resist% breach resistance · −$freqDown% intrusion frequency';
      case StaffRole.sales:
        final incomeUp = ((member.incomeMultiplier - 1) * 100).round();
        final priceUp = ((member.gridPriceMultiplier - 1) * 100).round();
        return '+$incomeUp% contract income · +$priceUp% export price';
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxed = member.level >= StaffMember.maxLevel;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GGColors.bg,
        border: Border.all(color: GGColors.panelBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(member.role.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.role.title,
                        style: GGText.body
                            .copyWith(fontWeight: FontWeight.w800)),
                    Text(member.role.domain, style: GGText.soft),
                  ],
                ),
              ),
              Text(
                maxed ? 'MAX' : 'Lv ${member.level}',
                style: GGText.body.copyWith(
                    fontWeight: FontWeight.w900,
                    color: maxed ? GGColors.amber : GGColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: member.levelProgress,
              minHeight: 6,
              backgroundColor: GGColors.panelBorder,
              color: maxed ? GGColors.amber : GGColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(_bonusLine(), style: GGText.soft),
        ],
      ),
    );
  }
}
