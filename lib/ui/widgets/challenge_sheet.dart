import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/challenge.dart';
import '../../data/zones.dart';
import '../../game/grid_guard_game.dart';
import '../../services/app_providers.dart';
import '../theme.dart';

/// The weekly challenge board: this week's brief, your standing on it, and a
/// result you can paste anywhere.
///
/// Comparing permanent sites is meaningless — whoever started first wins — so
/// this is the fair race: same seed, same week, same money, seven days.
Future<void> showChallengeSheet(
    BuildContext context, WidgetRef ref, GridGuardGame game) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: GGColors.panel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (ctx) => _ChallengeSheet(game: game, ref: ref),
  );
}

class _ChallengeSheet extends StatelessWidget {
  const _ChallengeSheet({required this.game, required this.ref});

  final GridGuardGame game;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final challenge = ChallengeCatalog.current();
    final profile = ref.read(profileProvider);
    final best = profile.challengeScores[challenge.week] ?? 0;
    final zone = ZoneCatalog.at(challenge.zoneIndex);
    final closes = ChallengeCatalog.endOfWeek();
    final left = closes.difference(DateTime.now().toUtc());

    // Your live standing, scored the same way the challenge is.
    final live = ChallengeCatalog.scoreFor(
      baseValue: game.baseValue,
      money: game.money.floor(),
      blackouts: game.blackoutCount,
      watt: game.coinsEarned,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: GGColors.amber),
                  const SizedBox(width: 8),
                  const Text('WEEKLY CHALLENGE', style: GGText.heading),
                  const Spacer(),
                  Text('closes in ${left.inDays}d ${left.inHours % 24}h',
                      style: GGText.soft),
                ],
              ),
              const SizedBox(height: 10),
              GGPanel(
                borderColor: GGColors.amber,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Week ${challenge.week} · ${challenge.name}',
                        style: GGText.body
                            .copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(challenge.blurb, style: GGText.soft),
                    const SizedBox(height: 8),
                    Text(
                        '${zone.emoji} ${zone.name} · '
                        '${challenge.startMoney}M seed · '
                        '${challenge.days} days · identical weather and raids '
                        'for every player',
                        style: GGText.soft.copyWith(
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Row('Your site right now', '${_short(live)}'),
              _Row('Your best this week', best == 0 ? '—' : _short(best)),
              const SizedBox(height: 12),
              Text(
                  'Score is what the site is worth plus cash and WATT, with a '
                  'penalty for every blackout — holding it intact is the skill '
                  'being measured.',
                  style: GGText.soft),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('COPY RESULT CARD'),
                  onPressed: () async {
                    final card = _resultCard(challenge, zone.name, live);
                    await Clipboard.setData(ClipboardData(text: card));
                    ref
                        .read(profileProvider.notifier)
                        .recordChallengeScore(challenge.week, live);
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Result copied — paste it anywhere.')),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Text(
                  'The card is plain text so it pastes into any chat, and it '
                  'names the week so anyone can check they ran the same one.',
                  style: GGText.soft),
            ],
          ),
        ),
      ),
    );
  }

  /// The shareable result. Deliberately text: it survives every app, and the
  /// week number is what makes two people's numbers comparable.
  String _resultCard(WeeklyChallenge c, String zoneName, int score) {
    final wattLine = game.coinsEarned > 0
        ? '\n₵${game.coinsEarned.toStringAsFixed(3)} mined'
        : '';
    return '⚡ GRID GUARD — Week ${c.week}: ${c.name}\n'
        '$zoneName · day ${game.dayNumber}\n'
        'Score ${_short(score)}\n'
        'Site ${_short(game.baseValue)} · ${game.raidCount} raids survived · '
        '${game.blackoutCount} blackouts$wattLine';
  }

  static String _short(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return '$v';
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: GGText.soft)),
          Text(value,
              style: GGText.body.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
