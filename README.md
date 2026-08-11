# Grid Guard

**Grid Guard** is a mobile **2.5D isometric tower-defense game** built with **Flutter + the [Flame](https://flame-engine.org) engine**.

You play the **Baş Mimar** ("Chief Architect"), defending a smart city's energy core — a **BESS 1M** battery-storage array and the **Core 40 PMDC** data center — from waves of autonomous sabotage drones and malware units. Build **PV Panel** farms to generate power (**MW**), throttle enemies with **Automated Scissor Barriers**, and vaporize grouped enemies with chaining **6300A Shock Transformers**.

## Visual language

Clean, minimalist, bright **industrial isometric** UI — not flat top-down. Light gray/white ground tiles, sharp-edged beveled structures with visible top/left/right face shading, thin blue/orange neon conduit lines, and floating `+MW` gain text. Reads like an engineering dashboard, not a fantasy game.

> **Art note:** All in-game visuals in this repo are **procedurally drawn placeholder shapes** (shaded isometric diamonds and boxes). Final production art (sprite sheets / atlases) is expected to be commissioned or generated separately and dropped in later. The rendering pipeline reads sprites/colors *per tower & enemy type from a catalog*, so swapping placeholders for real PNG atlases requires **no gameplay logic changes**.

## Progression & economy

- **30 levels across 5 Zones** (6 levels each). Each Zone shifts palette (industrial blue → critical orange) and ends with an **Overload Boss Wave**.
- **MW** — soft currency, per-run. Spent on placing/upgrading structures; resets each level.
- **Grid Credits** — permanent meta-currency, earned from level results.
- **Energy Cores** — hard currency (field wired, not yet granted by anything).
- **3-star scoring** per level: (1) survive, (2) low damage taken, (3) time/efficiency.

## Monetization (architected day one, no real SDK yet)

All ad/IAP calls live behind an abstract **`MonetizationService`** interface. The app ships with a **`MockMonetizationService`** so the whole game is playable and testable offline with zero ad SDK. Touchpoints:

- Rewarded ad — *2× MW reward* on victory, one-time *Continue* on defeat, daily-bonus double.
- Interstitial — only every 2–3 completed levels, on the level-transition screen, never mid-level or on level 1.
- Store — cosmetic skins & tower unlocks priced in Grid Credits / Energy Cores, plus a *Starter Pack* IAP tile.

Wiring a real SDK (`google_mobile_ads`, `in_app_purchase`) is a deliberate later phase — swap the `MonetizationService` implementation, touch no gameplay code.

## Architecture

```
lib/
  game/          Flame components, systems, the FlameGame
    components/  iso tiles, towers, enemies, core, pv panel, fx
    systems/     iso projection, depth sort, path, wave spawner, shake
  models/        pure data classes (profile, level state, catalogs, config)
  services/      save/load, monetization, audio, Riverpod providers
  ui/            Flutter widgets/HUD/screens overlaid on the game
  data/          level configs + tower/enemy catalogs
```

State management: **Riverpod**. Persistence: **shared_preferences**, fully offline.

## Build phases (this repo)

- **Phase 1 — Architecture & foundation:** isometric projection + depth sorting, data models, `SaveService`, `MockMonetizationService`, path system, level loader, placeholder rendering.
- **Phase 2 — Core gameplay:** PV economy, Scissor Barrier + Shock Transformer towers, wave spawner, 2 enemy types + boss wave, win/lose, 3-star scoring, mock rewarded-ad hooks.
- **Phase 3 — UI, game feel & store:** full HUD, level-select zone map, win/lose screens, store mockup, screen shake, geometric VFX, `AudioService` hooks, interstitial placement.

## Running

Requires the Flutter SDK (stable channel).

```bash
flutter pub get
flutter run           # attach a device or emulator
```

> This project was authored in an environment without the Flutter SDK, so it has **not been compiled against a device here**. Run `flutter pub get` and `flutter analyze` locally to catch any environment-specific fixups before the first device run.
