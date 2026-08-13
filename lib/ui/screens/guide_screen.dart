import 'package:flutter/material.dart';

import '../../data/dc_workload.dart';
import '../../data/grid_market.dart';
import '../../game/grid_guard_game.dart';
import '../theme.dart';

/// The manual. Grid Guard runs a real energy economy — generation, storage,
/// market pricing, contracts with security floors, unreliable intelligence —
/// and none of that is guessable from watching the meters. This screen states
/// the rules plainly so the player is making decisions instead of experiments.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How the site works')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const _Section(
            emoji: '⚡',
            title: 'Energy is the whole game',
            body: 'PV panels only produce in daylight. Wind turbines work day '
                'and night but the wind rises and falls. Everything you '
                'generate flows into your BESS batteries, and everything on '
                'site draws from them: the Data Centers earning your money, '
                'every shot a Shock Transformer fires, every interceptor '
                'drone, and the Intel Center.\n\n'
                'A quarter of your battery (up to 25) is reserved for '
                'defence — Data Centers cannot drain below it. That reserve '
                'is why your towers keep firing when the grid is tight.',
          ),
          _Section(
            emoji: '🖥',
            title: 'Contracts: money against heat',
            body: 'A Data Center earns nothing on its own — it runs a '
                'workload, and that choice is the central risk dial. Better '
                'paying data draws more attention and more power.\n\n'
                'Each contract has a security floor. You cannot store bank '
                'records on a site with two transformers; build defences '
                'first, then the job unlocks. Switching to a hotter contract '
                'does not summon a maximum raid instantly — heat climbs over '
                'about a minute, and the HUD shows the climb, which is your '
                'window to prepare.',
            table: _workloadTable,
          ),
          const _Section(
            emoji: '🌗',
            title: 'Days, nights and raids',
            body: 'One game day is 24 minutes: twelve of daylight, twelve of '
                'dark. Nothing attacks in daylight — that is when you build, '
                'repair, upgrade and trade.\n\n'
                'Not every night is raided. A quiet site is mostly left '
                'alone; a Gov Secrets site is watched constantly. When a raid '
                'does come, heat decides how heavy it is and the night gets '
                'split into waves. Raiders fly in from every edge and will '
                'attack ANY structure, not just your base.',
          ),
          const _Section(
            emoji: '📡',
            title: 'Intelligence is bought, never certain',
            body: 'An Intel Center forecasts which nights get raided. It is '
                'expensive three times over: a large build cost, MONEY and '
                'energy burned every second it runs, and it occupies Data '
                'Center compute — so knowing the future costs you earning '
                'capacity.\n\n'
                'And it can be wrong. A fresh centre is right only 30% of the '
                'time. Seven upgrade tiers take that to 40, 50, 62, 72, 82 and '
                'finally 90% — and it stops there. Never 100%. Each tier also '
                'costs more to run and takes more compute, so accuracy is a '
                'long campaign of reinvestment, not a purchase. A wrong '
                'reading is a confident '
                'wrong reading: it will tell you a night is quiet when it is '
                'not. The percentage next to the readout is how much you '
                'should trust it. A wrecked Intel Center reports nothing at '
                'all.',
          ),
          const _Section(
            emoji: '🔌',
            title: 'The electricity market',
            body: 'Power has a live price, and it moves the way a real '
                'solar-heavy grid moves: cheap around midday when every site '
                'in the zone is dumping solar, expensive at dusk and through '
                'the night when nothing is generating. Weather moves it for '
                'everyone — a storm dims the whole zone, not just you.\n\n'
                'Tap the meter in the HUD to buy from the grid: the site '
                'tops up whenever the battery falls below 35%, at whatever '
                'the market is asking. Selling is the other half, and it '
                'needs the Utility Interconnect. You always sell for less '
                'than you buy, and that spread is exactly why a large battery '
                'pays for itself: fill it when power is worthless, live off '
                'it when power is dear.',
          ),
          const _Section(
            emoji: '💥',
            title: 'Damage, repair and blackout',
            body: 'Structures take damage instead of vanishing. Below 30% '
                'health they stop working entirely — a dark transformer does '
                'not fire — and if ignored long enough they are destroyed and '
                'must be rebuilt at full price. Repairing is always far '
                'cheaper than rebuilding, so "Repair all" between nights is '
                'the habit to build.\n\n'
                'Losing the core does not end anything. It is a blackout: the '
                'raid breaks off, you lose a third of your cash, and the grid '
                'comes back at partial strength next morning. The site you '
                'built stays built.',
          ),
          const _Section(
            emoji: '💰',
            title: 'Three currencies, kept apart',
            body: 'MONEY (M) is the build currency: contracts, missions, the '
                'dawn bonus and grid sales all pay it, and it buys '
                'structures, upgrades, repairs and land clearing.\n\n'
                'WATT (⚡WTT) is minted by exactly one thing — the Crypto '
                'Mining workload — and buys permanent perks that carry across '
                'everything you do. You can cash WATT out for MONEY at '
                '${GridGuardGame.wattToCash} M each, but spent WATT is gone '
                'from your perk budget.\n\n'
                'Real money appears in one place only: the services sheet, '
                'which sells time — banked production, an emergency repair '
                'crew, capital. Nothing there is unreachable by playing.',
          ),
          const _Section(
            emoji: '🌳',
            title: 'The land',
            body: 'You can build anywhere except the base tile itself, but '
                'ground is not always free. Trees and rocks have to be '
                'cleared and ponds have to be drained and backfilled, and '
                'that bill is added to the build cost. The open middle of the '
                'yard is the cheapest real estate you have — spend it well.',
          ),
          const _Section(
            emoji: '🏦',
            title: 'While you are away',
            body: 'The site keeps running when the app is closed: up to eight '
                'hours of production at a reduced rate, waiting for you when '
                'you come back. It needs generation that can actually cover '
                'the draw, so an unpowered site banks nothing. The Night '
                'Shift Crew perk extends the window to sixteen hours.',
          ),
        ],
      ),
    );
  }
}

/// The contract table, generated from the same catalog the game reads, so it
/// cannot drift out of date.
Widget get _workloadTable {
  return Column(
    children: [
      for (final w in DcWorkloadCatalog.workloads)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 26, child: Text(w.emoji)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.name,
                        style:
                            GGText.body.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                        '${w.income.toStringAsFixed(0)}M/s · '
                        '${w.draw.toStringAsFixed(0)}⚡/s · '
                        'heat ${w.threat.toStringAsFixed(1)}x · '
                        'needs 🛡${w.requiredSecurity}'
                        '${w.minesCoins ? ' · mints WATT' : ''}',
                        style: GGText.soft),
                  ],
                ),
              ),
            ],
          ),
        ),
      Text(
          'Grid prices swing between about '
          '${GridMarket.basePrice.toStringAsFixed(2)}M and several times that; '
          'you sell for ${(GridMarket.sellFraction * 100).round()}% of the '
          'buying price.',
          style: GGText.soft),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.emoji,
    required this.title,
    required this.body,
    this.table,
  });

  final String emoji;
  final String title;
  final String body;
  final Widget? table;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GGPanel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: GGText.body
                          .copyWith(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(body, style: GGText.soft.copyWith(height: 1.45)),
            if (table != null) ...[
              const SizedBox(height: 12),
              table!,
            ],
          ],
        ),
      ),
    );
  }
}
