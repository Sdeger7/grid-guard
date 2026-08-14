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
                'After dark the site lights itself, and light is load: every '
                'building draws a little power to stay lit, so a sprawling '
                'site costs more to run through a long winter night than a '
                'compact one.\n\n'
                'A quarter of your battery (up to 25) is reserved for '
                'defence — Data Centers cannot drain below it. That reserve '
                'is why your towers keep firing when the grid is tight.',
          ),
          _Section(
            emoji: '🖥',
            title: 'Contracts: money against heat',
            body: 'A Data Center earns nothing on its own — it runs a '
                'contract, and that choice is the central risk dial. Better '
                'paying data draws more attention and more power.\n\n'
                'Every machine books its own work, so a site can mine WATT on '
                'DC 1 and host bank records on DC 2. You may run at most five, '
                'and the hottest contract on site sets the attention the whole '
                'site gets.\n\n'
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
                'attack ANY structure, not just your base — and they go for '
                'what hurts most: Data Centers running hot contracts first, '
                'then the Intel Center and your batteries, before anything '
                'cheap.',
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
                'Tap the meter in the HUD to open the power desk. There you '
                'see the spot price and sign fixed-term contracts against it: '
                'pick a term of one to eight in-game hours and a rate, and '
                'the price is locked for the whole term whatever the market '
                'does next. Buy cheap at midday and you carry that price '
                'through the evening peak.\n\n'
                'Selling is a commitment, not a bonus. You have to actually '
                'deliver the rate you signed for, and anything you cannot '
                'supply is bought on your behalf at a punitive imbalance rate '
                '— though your defence reserve is never touched to fill a '
                'contract. You can also leave "top up at spot" on to buy '
                'automatically below 35% battery, which is convenient and '
                'usually the worst price you will pay.\n\n'
                'You always sell for less than you buy, and that spread is '
                'exactly why a large battery pays for itself: fill it when '
                'power is worthless, live off it when power is dear.',
          ),
          const _Section(
            emoji: '🎛️',
            title: 'Your own controls',
            body: 'Towers fire themselves, so the row above the build tray is '
                'how you actually fight a raid. Each one is a trade, and each '
                'has a long cooldown, so spending one early is a decision you '
                'can regret.\n\n'
                '⚡ Overcharge — transformers hit twice as hard and burn twice '
                'the energy for 20 seconds.\n'
                '⏹️ Emergency Stop — Data Centers go dark for 30 seconds. No '
                'income, no mining, but every joule goes to the guns.\n'
                '🌑 Go Dark — kill the lights for 10 seconds and raiders lose '
                'their targets entirely and scatter.\n'
                '🔧 Crew Callout — patch everything damaged by 30% instantly, '
                'paid for in energy rather than cash.',
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
                'WATT (₵WATT) is minted by exactly one thing — the Crypto '
                'Mining workload — and buys permanent perks that carry across '
                'everything you do. You can cash WATT out for MONEY at '
                '${GridGuardGame.wattToCash} M each, but spent WATT is gone '
                'from your perk budget.\n\n'
                'Real money appears in one place only: the services sheet, '
                'which sells time — banked production, an emergency repair '
                'crew, capital. Nothing there is unreachable by playing, and '
                'WATT is never for sale at any price. It is a closed currency: '
                'mined in-game, spent in-game — on permanent perks, and on the '
                'wardrobe, where it buys looks and nothing else.',
          ),
          const _Section(
            emoji: '📈',
            title: 'Upgrades never run out',
            body: 'Every structure can be upgraded forever. Past the first '
                'few tiers each step costs roughly 2.2x the last and produces '
                'about 1.14x more, so an upgrade is always in reach and never '
                'quite cheap — the site is never finished.\n\n'
                'Everything standing also costs money every second to keep '
                'standing, billed against what it is worth. A bigger site has '
                'a bigger running bill, which is why cash cannot simply pile '
                'up: income has to keep pace with what you have built. The '
                'facilities line shows your current upkeep.',
          ),
          const _Section(
            emoji: '📅',
            title: 'The week',
            body: 'A world event runs most weeks, the same one for everybody, '
                'Monday to Sunday. Drought Week doubles power prices. A '
                'Regional Blackout means nothing can be bought at any price '
                'and every contract pays a premium to whoever can still '
                'deliver. Gale Season is a wind week. Crackdown brings harder '
                'raids and hazard rates. A Compute Boom pays half again on '
                'contracts and mining. A Solar Glut drops prices through the '
                'floor — fill your batteries and sell nothing.\n\n'
                'One week in four is quiet, so an event landing is actually '
                'news. The morning card tells you which week you are in.',
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
                        '${(w.income * 3600).toStringAsFixed(0)}M/h · '
                        '${(w.draw * 3600).toStringAsFixed(0)}⚡/h · '
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
