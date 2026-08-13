import 'package:flutter/foundation.dart';

/// A place to build a site.
///
/// Relocating is the long game's reset: you sell up, the buildings stay behind,
/// and you start again somewhere harder and richer with your WATT and your
/// permanent perks intact. Each zone rewrites the physics of the site — how
/// much sun and wind it gets, what power trades for there, and how much
/// attention it draws — so the same base plan does not work twice.
@immutable
class SiteZone {
  const SiteZone({
    required this.id,
    required this.name,
    required this.emoji,
    required this.blurb,
    required this.sunScale,
    required this.windScale,
    required this.priceScale,
    required this.threatScale,
    required this.incomeScale,
    required this.unlockDay,
  });

  final String id;
  final String name;
  final String emoji;
  final String blurb;

  /// Multipliers on solar yield, wind yield, grid prices, raid pressure and
  /// contract income for a site built here.
  final double sunScale;
  final double windScale;
  final double priceScale;
  final double threatScale;
  final double incomeScale;

  /// Days you must survive in the previous zone before this one opens.
  final int unlockDay;
}

class ZoneCatalog {
  static const List<SiteZone> zones = [
    SiteZone(
      id: 'meadow',
      name: 'Karaca Meadow',
      emoji: '🌾',
      blurb: 'Mild, green, unremarkable. Decent sun, steady wind, and nobody '
          'much cares what you do here.',
      sunScale: 1.0,
      windScale: 1.0,
      priceScale: 1.0,
      threatScale: 1.0,
      incomeScale: 1.0,
      unlockDay: 0,
    ),
    SiteZone(
      id: 'coast',
      name: 'Salt Coast',
      emoji: '🌊',
      blurb: 'Relentless wind off the water and cloud half the week. Power '
          'trades higher here — the mainland is always short.',
      sunScale: 0.8,
      windScale: 1.6,
      priceScale: 1.25,
      threatScale: 1.15,
      incomeScale: 1.15,
      unlockDay: 12,
    ),
    SiteZone(
      id: 'basin',
      name: 'Ash Basin',
      emoji: '🏜️',
      blurb: 'Brutal sun, dead air, no neighbours. Solar heaven if your '
          'batteries can hold the day until dark.',
      sunScale: 1.5,
      windScale: 0.5,
      priceScale: 1.15,
      threatScale: 1.35,
      incomeScale: 1.35,
      unlockDay: 16,
    ),
    SiteZone(
      id: 'ridge',
      name: 'Storm Ridge',
      emoji: '⛰️',
      blurb: 'Weather comes through in walls. Enormous wind, unreliable sun, '
          'and the highest prices on the map.',
      sunScale: 0.65,
      windScale: 2.0,
      priceScale: 1.5,
      threatScale: 1.6,
      incomeScale: 1.6,
      unlockDay: 20,
    ),
    SiteZone(
      id: 'capital',
      name: 'Capital Fringe',
      emoji: '🏙️',
      blurb: 'On the edge of the city that turned the lights off. Every '
          'contract pays double, and every one of them is watched.',
      sunScale: 0.95,
      windScale: 0.9,
      priceScale: 1.8,
      threatScale: 2.1,
      incomeScale: 2.0,
      unlockDay: 25,
    ),
  ];

  static SiteZone at(int index) =>
      zones[index.clamp(0, zones.length - 1)];

  static bool hasNextAfter(int index) => index + 1 < zones.length;

  /// The zone you would move to next, or null at the end of the map.
  static SiteZone? nextAfter(int index) =>
      hasNextAfter(index) ? zones[index + 1] : null;
}
