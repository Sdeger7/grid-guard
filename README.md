# Grid Guard

A working simulation of the energy business — generation, storage, data centres,
mining and the power market — that happens to have drones attacking it at night.

Built with **Flutter** and the **[Flame](https://flame-engine.org)** engine.
Fully playable offline.

> Store copy, positioning and press angles live in
> [`docs/store-listing.md`](docs/store-listing.md).

---

## What the game is

You run an independent power site in a zone the utility gave up on. Panels
generate when the sun is actually up over your province; turbines run when the
wind is really blowing; batteries carry you through the dark. Data centres burn
that power to earn money — or to mine ⚡WATT. And every night, raiders come for
the most valuable thing you have built.

The simulation is the product. The raids are the only invented part.

## What is real

| System | How it works |
| --- | --- |
| **Solar** | Computed from the site's real latitude and longitude on today's date: declination, hour angle, equation of time, air mass. Seasons and day length come free. |
| **Weather** | Live cloud, wind and temperature for the site's coordinates, cached, with a simulated fallback so the game never needs a network. |
| **Locations** | 21 real places across five regions, carrying their published solar and wind resource, local power prices and land prices. |
| **Market** | Prices follow the duck curve — cheap at midday, dear after dark — moved by weather, the day, and a real-clock evening peak. |
| **Contracts** | Fixed term, locked price. Fail to deliver on a sell and the shortfall is bought on your behalf at 1.6× spot. |
| **Mining** | ⚡WATT is capped at 2,500,000. Difficulty rises as the reserve empties, so the total approaches the cap and can never cross it. |

## The loop

**Day** is safe: build, upgrade, repair, trade, take contracts. **Night** brings
one to three announced raid windows. Be present and you fight them with manual
abilities; be absent and your automated defences meet them alone and you read
the damage in the morning.

Losing the core is a **blackout** — you lose cash and come back at partial
strength — never a game over. The site is permanent, autosaved, and keeps
producing while the app is closed.

## Economy

Three currencies, kept strictly apart:

- **MONEY (M)** — the build currency. Contracts, grid sales, missions and the
  dawn bonus pay it; structures, upgrades, repairs, land and clearing cost it.
- **⚡WATT (₵)** — minted only by a data centre running Crypto Mining, which
  pays no cash at all. Buys permanent perks and cosmetics. Capped, and **never
  purchasable with real money** — that rule is what keeps the tournament
  economy lawful, and it is not negotiable.
- **Real money** — sold in exactly one place, and only ever buys **time and
  paint**: banked production, a repair crew, capital, cosmetics, the season
  pass. Never power.

Weekly tournaments run on an entry fee paid into a prize pool, distributed by
finishing position. The share the places do not take returns to the
**treasury**, which is where streak and event rewards are paid from — so no WATT
is ever minted for a reward, and none is ever destroyed.

## Fairness

The permanent site is the personal lane, where everything above is sold. The
**weekly challenge is the compared lane**, and nothing bought reaches it: perks
resolve to none, the season pass does not apply, premium land cannot be taken
and speed-ups refuse outright — enforced in the game rather than hidden in the
UI. Everyone runs the same seed, the same weather, the same raid calendar and
the same seed capital, from nothing, for seven days.

## Structures

PV panels, wind turbines, BESS storage, data centres (five contract types, up to
five machines, each booking its own work), drone bays, scissor barriers, shock
transformers, and the intel centre — seven upgrade tiers of forecasting that is
never more than 90% accurate.

Upgrades never run out: past the hand-written tiers each step costs 2.2× the
last for 1.14× the output, so there is always a next purchase and it is always
slightly out of reach.

## Running it

```bash
flutter pub get
flutter run                     # device or emulator
flutter run -d chrome           # web
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0   # remote/codespace
```

Android builds are produced by CI on every push, per-ABI, and published to the
rolling `latest` release:

```
https://github.com/Sdeger7/grid-guard/releases/download/latest/grid-guard-arm64.apk
```

## Art

In-game visuals are a mix of commissioned sprites and procedurally drawn
shapes. Every structure reads its palette from the equipped **skin** and its
sprite from a catalog key, so hand-drawn art can replace any of it without a
line of gameplay code changing.

## Layout

```
lib/
  data/        catalogs and rules: towers, workloads, cities, weather, market,
               abilities, skins, challenges, WATT supply
  game/        the Flame game: components, systems, the economy tick
  models/      saves, profile, level state, land holdings, contracts
  services/    persistence, weather, leaderboard, monetization seams
  ui/          screens and sheets
```
