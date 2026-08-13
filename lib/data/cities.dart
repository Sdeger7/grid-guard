import 'package:flutter/foundation.dart';

/// A real place to build a site.
///
/// Zones used to be invented multipliers. These are actual provinces with
/// actual coordinates, so the sun that rises over your site is the sun that
/// rises over that city today, at that time of year. The solar and wind figures
/// come from Türkiye's published potential maps, which is why Konya is a solar
/// site and Çanakkale is a wind site — the game is not making that up.
@immutable
class City {
  const City({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.solarIndex,
    required this.windIndex,
    required this.landPrice,
    required this.priceIndex,
    required this.threatIndex,
    required this.blurb,
  });

  final String id;
  final String name;

  final double latitude;
  final double longitude;

  /// Annual solar yield relative to the national average (GEPA-style).
  final double solarIndex;

  /// Wind potential relative to the national average (REPA-style).
  final double windIndex;

  /// What a plot costs here. Land near the big load centres is dear; the
  /// steppe is cheap, which is the whole trade.
  final int landPrice;

  /// What power trades for locally — high where demand is concentrated.
  final double priceIndex;

  /// How much attention an operation draws here.
  final double threatIndex;

  final String blurb;
}

class CityCatalog {
  static const List<City> cities = [
    City(
      id: 'istanbul',
      name: 'İstanbul',
      latitude: 41.01,
      longitude: 28.98,
      solarIndex: 0.82,
      windIndex: 1.05,
      landPrice: 9000,
      priceIndex: 1.35,
      threatIndex: 1.4,
      blurb: 'Weak sun, expensive ground, and the highest power prices in the '
          'country. You are selling into the biggest load in Türkiye.',
    ),
    City(
      id: 'konya',
      name: 'Konya',
      latitude: 37.87,
      longitude: 32.48,
      solarIndex: 1.28,
      windIndex: 0.85,
      landPrice: 1200,
      priceIndex: 0.9,
      threatIndex: 0.85,
      blurb: 'The steppe: enormous sun, cheap flat land for miles, and nobody '
          'looking. The classic first solar site.',
    ),
    City(
      id: 'canakkale',
      name: 'Çanakkale',
      latitude: 40.15,
      longitude: 26.41,
      solarIndex: 0.95,
      windIndex: 1.55,
      landPrice: 2600,
      priceIndex: 1.05,
      threatIndex: 0.95,
      blurb: 'Wind country. The straits blow almost every day of the year — '
          'turbines here earn through the night.',
    ),
    City(
      id: 'izmir',
      name: 'İzmir',
      latitude: 38.42,
      longitude: 27.14,
      solarIndex: 1.12,
      windIndex: 1.35,
      landPrice: 5200,
      priceIndex: 1.2,
      threatIndex: 1.15,
      blurb: 'The rare site with both: strong coastal wind and real sun, at a '
          'price that reflects it.',
    ),
    City(
      id: 'antalya',
      name: 'Antalya',
      latitude: 36.90,
      longitude: 30.69,
      solarIndex: 1.30,
      windIndex: 0.7,
      landPrice: 6400,
      priceIndex: 1.15,
      threatIndex: 1.05,
      blurb: 'The best sun in the country and almost no wind. Long summer '
          'days, and nights you have to store for.',
    ),
    City(
      id: 'sanliurfa',
      name: 'Şanlıurfa',
      latitude: 37.16,
      longitude: 38.79,
      solarIndex: 1.35,
      windIndex: 0.75,
      landPrice: 900,
      priceIndex: 0.85,
      threatIndex: 1.1,
      blurb: 'Brutal southern sun, the cheapest land on the map, and summers '
          'that punish anything without cooling.',
    ),
    City(
      id: 'erzurum',
      name: 'Erzurum',
      latitude: 39.90,
      longitude: 41.27,
      solarIndex: 1.05,
      windIndex: 1.1,
      landPrice: 800,
      priceIndex: 0.95,
      threatIndex: 0.8,
      blurb: 'High, cold and clear. Thin air means strong sun at altitude — '
          'and the shortest winter days in the country.',
    ),
    City(
      id: 'ankara',
      name: 'Ankara',
      latitude: 39.93,
      longitude: 32.86,
      solarIndex: 1.08,
      windIndex: 0.95,
      landPrice: 4200,
      priceIndex: 1.15,
      threatIndex: 1.5,
      blurb: 'Central, well connected, and closely watched. Everything here '
          'is somebody official\'s business.',
    ),
    City(
      id: 'trabzon',
      name: 'Trabzon',
      latitude: 41.00,
      longitude: 39.72,
      solarIndex: 0.72,
      windIndex: 0.9,
      landPrice: 3100,
      priceIndex: 1.1,
      threatIndex: 0.9,
      blurb: 'The Black Sea coast: cloud, rain and the weakest sun in Türkiye. '
          'A site here is a test of everything except solar.',
    ),
    City(
      id: 'mugla',
      name: 'Muğla',
      latitude: 37.22,
      longitude: 28.36,
      solarIndex: 1.22,
      windIndex: 1.25,
      landPrice: 4800,
      priceIndex: 1.1,
      threatIndex: 0.95,
      blurb: 'Aegean sun with a sea breeze behind it. Balanced, beautiful and '
          'not cheap.',
    ),
  ];

  static City byId(String id) =>
      cities.firstWhere((c) => c.id == id, orElse: () => cities[1]);

  static int indexOf(String id) {
    final i = cities.indexWhere((c) => c.id == id);
    return i < 0 ? 1 : i;
  }

  /// What it costs to move an operation from [from] to [to]: the new plot, plus
  /// hauling what cannot simply be left behind.
  static int relocationCost(City from, City to) {
    const haulage = 2500;
    return to.landPrice + haulage;
  }
}
