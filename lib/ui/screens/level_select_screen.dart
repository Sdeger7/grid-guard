import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/levels.dart';
import '../../data/zone_theme.dart';
import '../../models/player_profile.dart';
import '../../services/app_providers.dart';
import '../theme.dart';
import '../widgets/star_row.dart';
import 'game_screen.dart';

/// Zone-map level select: 5 zones of 6 levels each, with locked/unlocked state
/// and per-level star records read from the persistent profile.
class LevelSelectScreen extends ConsumerWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: GGColors.panel,
        surfaceTintColor: GGColors.panel,
        title: const Text('SELECT SECTOR', style: GGText.heading),
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: GGColors.panelBorder),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 5,
        itemBuilder: (context, i) => _ZoneCard(zone: i + 1, profile: profile),
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({required this.zone, required this.profile});
  final int zone;
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = ZoneTheme.forZone(zone);
    final unlocked = zone <= profile.highestZoneReached;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GGPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 12, height: 12, color: theme.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(theme.name,
                      style: GGText.heading
                          .copyWith(color: unlocked ? GGColors.ink : GGColors.inkSoft)),
                ),
                if (!unlocked)
                  const Icon(Icons.lock_rounded,
                      size: 16, color: GGColors.inkSoft),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var idx = 1; idx <= 6; idx++) ...[
                  Expanded(
                      child: _LevelTile(
                          zone: zone, indexInZone: idx, profile: profile)),
                  if (idx < 6) const SizedBox(width: 6),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.zone,
    required this.indexInZone,
    required this.profile,
  });
  final int zone;
  final int indexInZone;
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final config = LevelCatalog.byZoneIndex(zone, indexInZone);
    final unlocked = profile.isLevelUnlocked(zone, indexInZone);
    final stars = profile.starsFor(config.id);
    final isBoss = config.isZoneFinale;

    return GestureDetector(
      onTap: unlocked
          ? () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => GameScreen(config: config),
              ))
          : null,
      child: AspectRatio(
        aspectRatio: 0.82,
        child: Container(
          decoration: BoxDecoration(
            color: unlocked ? GGColors.bg : const Color(0xFFEDEFF2),
            border: Border.all(
              color: isBoss && unlocked ? GGColors.danger : GGColors.panelBorder,
              width: isBoss ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!unlocked)
                const Icon(Icons.lock_rounded, color: GGColors.inkSoft, size: 18)
              else ...[
                Text('${config.indexInZone}',
                    style: GGText.stat.copyWith(
                        color: isBoss ? GGColors.danger : GGColors.ink)),
                if (isBoss)
                  const Text('BOSS', style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: GGColors.danger)),
                const SizedBox(height: 2),
                StarRow(filled: stars, size: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
