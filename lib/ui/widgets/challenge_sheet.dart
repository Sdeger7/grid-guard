import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/challenge.dart';
import '../../data/cities.dart';
import '../../game/grid_guard_game.dart';
import '../../services/app_providers.dart';
import '../../data/levels.dart';
import '../../services/leaderboard_service.dart';
import '../screens/game_screen.dart';
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
    final field = ChallengeCatalog.benchmarkField(challenge);
    final pool = (field.length + 1) * ChallengeCatalog.entryFee;
    final entered = profile.challengeEntered[challenge.week] == true;
    final city = CityCatalog.cities[
        challenge.cityIndex.clamp(0, CityCatalog.cities.length - 1)];
    final closes = ChallengeCatalog.endOfWeek();
    final left = closes.difference(DateTime.now().toUtc());

    // Your live standing, scored the same way the challenge is.
    final live = ChallengeCatalog.scoreFor(
      baseValue: game.baseValue,
      money: game.money.floor(),
      blackouts: game.blackoutCount,
      watt: game.coinsEarned,
    );
    final liveRank = ChallengeCatalog.rankOf(live, field);

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
                        '📍 ${city.name} · '
                        '${formatCredits(challenge.startMoney)} seed · '
                        '${challenge.days} days · identical weather and raids '
                        'for every player',
                        style: GGText.soft.copyWith(
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // The pool. Everyone pays the same entry and the pool is paid
              // back by finishing position — the entry is WATT, which is
              // earned and spent only in-game.
              Row(
                children: [
                  Text('PRIZE POOL',
                      style: GGText.soft.copyWith(
                          letterSpacing: 1.2, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('$wattSymbol${pool.toStringAsFixed(2)} · ${field.length + 1} entries',
                      style: GGText.soft.copyWith(
                          color: GGColors.amber,
                          fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 6),
              for (final row in const [
                ('1st', 0.25),
                ('2nd', 0.15),
                ('3rd', 0.10),
                ('4th–10th', 0.03),
                ('11th–20th', 0.015),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text(row.$1, style: GGText.soft)),
                      Text('$wattSymbol${(pool * row.$2).toStringAsFixed(2)}',
                          style: GGText.soft.copyWith(
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              GGPanel(
                padding: const EdgeInsets.all(10),
                borderColor: entered ? GGColors.good : GGColors.panelBorder,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                          entered
                              ? 'Entered · currently standing #$liveRank of '
                                  '${field.length + 1}'
                              : 'Entry $wattSymbol${ChallengeCatalog.entryFee} — one '
                                  'per week',
                          style: GGText.soft.copyWith(
                              fontWeight: FontWeight.w700)),
                    ),
                    if (!entered)
                      FilledButton(
                        onPressed:
                            profile.coins >= ChallengeCatalog.entryFee
                                ? () async {
                                    await ref
                                        .read(profileProvider.notifier)
                                        .enterChallenge(challenge.week,
                                            ChallengeCatalog.entryFee);
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  }
                                : null,
                        child: const Text('ENTER'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                  'The field is a benchmark ladder for now — runs generated '
                  'from this week\'s seed, identical for every player, so a '
                  'position means the same thing to everyone. Real entries '
                  'replace it when the game goes online.',
                  style: GGText.soft),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(best > 0
                      ? 'CONTINUE THIS WEEK\'S RUN'
                      : 'START THIS WEEK\'S RUN'),
                  onPressed: () async {
                    // A new week wipes last week's attempt: everyone racing the
                    // same seed is the entire point.
                    final save = ref.read(saveServiceProvider);
                    if (save.challengeWeek != challenge.week) {
                      await save.clearBase(challenge: true);
                      await save.setChallengeWeek(challenge.week);
                    }
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => GameScreen(
                        config: LevelCatalog.survival,
                        challenge: true,
                      ),
                    ));
                  },
                ),
              ),
              const SizedBox(height: 6),
              Text(
                  'A challenge run is separate from your site and starts from '
                  'nothing. Perks, premium ground and anything bought are '
                  'switched off — the only difference between two results is '
                  'the decisions.',
                  style: GGText.soft),
              const SizedBox(height: 14),
              _Row('This run right now', '${_short(live)}'),
              _Row('Your best this week', best == 0 ? '—' : _short(best)),
              const SizedBox(height: 12),
              Text(
                  'Score is what the site is worth plus cash and WATT, with a '
                  'penalty for every blackout — holding it intact is the skill '
                  'being measured. Entry is free and nothing is ever taken '
                  'away.',
                  style: GGText.soft),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('COPY RESULT CARD'),
                  onPressed: () async {
                    final card = _resultCard(challenge, city.name, live);
                    await Clipboard.setData(ClipboardData(text: card));
                    ref
                        .read(profileProvider.notifier)
                        .recordChallengeScore(challenge.week, live);
                    // Recorded locally today; the same call reaches a server
                    // the day one exists.
                    ref.read(leaderboardProvider).submit(LeaderboardEntry(
                          week: challenge.week,
                          name: 'You',
                          score: live,
                          city: city.name,
                          days: game.dayNumber,
                        ));
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
              const SizedBox(height: 16),
              Text('YOUR PAST WEEKS',
                  style: GGText.soft.copyWith(
                      letterSpacing: 1.2, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              FutureBuilder<List<LeaderboardEntry>>(
                future: ref.read(leaderboardProvider).history(),
                builder: (_, snap) {
                  final rows = snap.data ?? const <LeaderboardEntry>[];
                  if (rows.isEmpty) {
                    return Text('No results yet — this is week one for you.',
                        style: GGText.soft);
                  }
                  return Column(
                    children: [
                      for (final e in rows.take(8))
                        _Row('Week ${e.week} · ${e.city}', _short(e.score)),
                    ],
                  );
                },
              ),
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
        ? '\n$wattSymbol${game.coinsEarned.toStringAsFixed(3)} mined'
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
