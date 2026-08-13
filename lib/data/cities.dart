import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Where in the world a site can stand.
///
/// Real places with real coordinates, so the sun that rises over a site is the
/// sun that rises over that city today. Solar and wind figures follow published
/// resource maps, which is why Ordos is a wind site, Seville is a solar one and
/// Hamburg is neither — the game is not inventing that.
///
/// The very best ground on earth — the Atacama, Aswan, the Gobi — is marked
/// [premium] and stays locked. Those are not starter locations; they are what a
/// long-running operation eventually earns its way into.
@immutable
class City {
  const City({
    required this.id,
    required this.name,
    required this.country,
    required this.region,
    required this.latitude,
    required this.longitude,
    required this.solarIndex,
    required this.windIndex,
    required this.landPrice,
    required this.priceIndex,
    required this.threatIndex,
    required this.blurb,
    this.premium = false,
  });

  final String id;
  final String name;
  final String country;
  final CityRegion region;

  final double latitude;
  final double longitude;

  /// Annual solar yield relative to a world average site.
  final double solarIndex;

  /// Wind resource relative to a world average site.
  final double windIndex;

  /// Freehold price for a plot here. Rent is derived from it.
  final int landPrice;

  /// What power trades for locally.
  final double priceIndex;

  /// How much attention an operation draws.
  final double threatIndex;

  final String blurb;

  /// Locked behind a purchase. Reserved for the exceptional ground.
  final bool premium;

  /// Yearly rent, as a fraction of the freehold price. Renting is cheap to
  /// start and expensive to keep — which is exactly the trade a real developer
  /// weighs.
  int get rentPerDay => math.max(1, (landPrice * 0.012).round());

  /// Great-circle distance to another city, in kilometres. This is what
  /// transmission between two of your own sites is priced on.
  double distanceTo(City other) {
    const earthRadiusKm = 6371.0;
    double rad(double d) => d * math.pi / 180.0;
    final dLat = rad(other.latitude - latitude);
    final dLon = rad(other.longitude - longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(latitude)) *
            math.cos(rad(other.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

enum CityRegion { turkiye, europe, americas, centralAsia, eastAsia }

extension CityRegionLabel on CityRegion {
  String get label {
    switch (this) {
      case CityRegion.turkiye:
        return 'Türkiye';
      case CityRegion.europe:
        return 'Europe';
      case CityRegion.americas:
        return 'Americas';
      case CityRegion.centralAsia:
        return 'Central Asia';
      case CityRegion.eastAsia:
        return 'East Asia';
    }
  }
}

class CityCatalog {
  static const List<City> cities = [
    // ---- Türkiye ----
    City(
      id: 'konya',
      name: 'Konya',
      country: 'Türkiye',
      region: CityRegion.turkiye,
      latitude: 37.87,
      longitude: 32.48,
      solarIndex: 1.18,
      windIndex: 0.85,
      landPrice: 1200,
      priceIndex: 0.9,
      threatIndex: 0.85,
      blurb: 'Steppe: strong sun, cheap flat land for miles, nobody looking.',
    ),
    City(
      id: 'canakkale',
      name: 'Çanakkale',
      country: 'Türkiye',
      region: CityRegion.turkiye,
      latitude: 40.15,
      longitude: 26.41,
      solarIndex: 0.92,
      windIndex: 1.5,
      landPrice: 2600,
      priceIndex: 1.05,
      threatIndex: 0.95,
      blurb: 'The straits blow almost every day. Turbines earn overnight here.',
    ),
    City(
      id: 'sanliurfa',
      name: 'Şanlıurfa',
      country: 'Türkiye',
      region: CityRegion.turkiye,
      latitude: 37.16,
      longitude: 38.79,
      solarIndex: 1.26,
      windIndex: 0.75,
      landPrice: 900,
      priceIndex: 0.85,
      threatIndex: 1.1,
      blurb: 'Hard southern sun and the cheapest ground in the country.',
    ),
    City(
      id: 'istanbul',
      name: 'İstanbul',
      country: 'Türkiye',
      region: CityRegion.turkiye,
      latitude: 41.01,
      longitude: 28.98,
      solarIndex: 0.8,
      windIndex: 1.05,
      landPrice: 9000,
      priceIndex: 1.35,
      threatIndex: 1.4,
      blurb: 'Weak sun, dear ground, and the biggest load on the map to sell into.',
    ),

    // ---- Europe ----
    City(
      id: 'seville',
      name: 'Seville',
      country: 'Spain',
      region: CityRegion.europe,
      latitude: 37.39,
      longitude: -5.98,
      solarIndex: 1.25,
      windIndex: 0.85,
      landPrice: 5200,
      priceIndex: 1.1,
      threatIndex: 0.9,
      blurb: 'Andalusian sun with a European grid behind it.',
    ),
    City(
      id: 'aberdeen',
      name: 'Aberdeen',
      country: 'Scotland',
      region: CityRegion.europe,
      latitude: 57.15,
      longitude: -2.09,
      solarIndex: 0.55,
      windIndex: 1.75,
      landPrice: 3400,
      priceIndex: 1.25,
      threatIndex: 0.85,
      blurb: 'Almost no winter sun and North Sea wind that never stops.',
    ),
    City(
      id: 'hamburg',
      name: 'Hamburg',
      country: 'Germany',
      region: CityRegion.europe,
      latitude: 53.55,
      longitude: 9.99,
      solarIndex: 0.62,
      windIndex: 1.35,
      landPrice: 7800,
      priceIndex: 1.4,
      threatIndex: 1.1,
      blurb: 'Grey, windy, and paying the highest prices in Europe.',
    ),
    City(
      id: 'athens',
      name: 'Athens',
      country: 'Greece',
      region: CityRegion.europe,
      latitude: 37.98,
      longitude: 23.73,
      solarIndex: 1.2,
      windIndex: 1.1,
      landPrice: 4600,
      priceIndex: 1.15,
      threatIndex: 0.95,
      blurb: 'Aegean sun, meltemi wind, and an island grid that always needs more.',
    ),

    // ---- Americas ----
    City(
      id: 'phoenix',
      name: 'Phoenix',
      country: 'USA',
      region: CityRegion.americas,
      latitude: 33.45,
      longitude: -112.07,
      solarIndex: 1.3,
      windIndex: 0.7,
      landPrice: 4800,
      priceIndex: 1.05,
      threatIndex: 1.0,
      blurb: 'Desert sun and desert heat, right beside a growing load.',
    ),
    City(
      id: 'amarillo',
      name: 'Amarillo',
      country: 'USA',
      region: CityRegion.americas,
      latitude: 35.22,
      longitude: -101.83,
      solarIndex: 1.12,
      windIndex: 1.6,
      landPrice: 1600,
      priceIndex: 0.85,
      threatIndex: 0.9,
      blurb: 'The Texas panhandle: wind and sun together, land for nothing.',
    ),
    City(
      id: 'chihuahua',
      name: 'Chihuahua',
      country: 'Mexico',
      region: CityRegion.americas,
      latitude: 28.63,
      longitude: -106.08,
      solarIndex: 1.28,
      windIndex: 0.95,
      landPrice: 1100,
      priceIndex: 0.9,
      threatIndex: 1.2,
      blurb: 'High desert sun, cheap ground, and a long way from anyone helpful.',
    ),
    City(
      id: 'saopaulo',
      name: 'São Paulo',
      country: 'Brazil',
      region: CityRegion.americas,
      latitude: -23.55,
      longitude: -46.63,
      solarIndex: 0.98,
      windIndex: 0.85,
      landPrice: 5600,
      priceIndex: 1.2,
      threatIndex: 1.3,
      blurb: 'Southern hemisphere: your winter is their summer, and the load is enormous.',
    ),

    // ---- Central Asia ----
    City(
      id: 'almaty',
      name: 'Almaty',
      country: 'Kazakhstan',
      region: CityRegion.centralAsia,
      latitude: 43.24,
      longitude: 76.89,
      solarIndex: 1.05,
      windIndex: 1.15,
      landPrice: 1000,
      priceIndex: 0.8,
      threatIndex: 1.05,
      blurb: 'Mountain light, continental extremes, land at giveaway prices.',
    ),
    City(
      id: 'tashkent',
      name: 'Tashkent',
      country: 'Uzbekistan',
      region: CityRegion.centralAsia,
      latitude: 41.30,
      longitude: 69.24,
      solarIndex: 1.15,
      windIndex: 0.8,
      landPrice: 850,
      priceIndex: 0.75,
      threatIndex: 1.1,
      blurb: 'Long dry summers and a grid short of everything.',
    ),
    City(
      id: 'ulaanbaatar',
      name: 'Ulaanbaatar',
      country: 'Mongolia',
      region: CityRegion.centralAsia,
      latitude: 47.89,
      longitude: 106.91,
      solarIndex: 1.1,
      windIndex: 1.45,
      landPrice: 700,
      priceIndex: 0.85,
      threatIndex: 0.9,
      blurb: 'Brutal cold, clear skies and steppe wind. Panels love the cold.',
    ),

    // ---- East Asia ----
    City(
      id: 'ordos',
      name: 'Ordos',
      country: 'China',
      region: CityRegion.eastAsia,
      latitude: 39.61,
      longitude: 109.78,
      solarIndex: 1.22,
      windIndex: 1.5,
      landPrice: 1400,
      priceIndex: 0.8,
      threatIndex: 1.15,
      blurb: 'Desert plateau with both resources at once, and coal money nearby.',
    ),
    City(
      id: 'kashgar',
      name: 'Kashgar',
      country: 'China',
      region: CityRegion.eastAsia,
      latitude: 39.47,
      longitude: 75.99,
      solarIndex: 1.24,
      windIndex: 0.9,
      landPrice: 950,
      priceIndex: 0.75,
      threatIndex: 1.25,
      blurb: 'Far west, far from everything, and the sun does not care.',
    ),
    City(
      id: 'jaisalmer',
      name: 'Jaisalmer',
      country: 'India',
      region: CityRegion.eastAsia,
      latitude: 26.91,
      longitude: 70.92,
      solarIndex: 1.29,
      windIndex: 1.25,
      landPrice: 1000,
      priceIndex: 0.85,
      threatIndex: 1.1,
      blurb: 'Thar desert: sun, wind and dust in equal measure.',
    ),

    // ---- Premium: the exceptional ground ----
    City(
      id: 'atacama',
      name: 'Atacama',
      country: 'Chile',
      region: CityRegion.americas,
      latitude: -23.86,
      longitude: -69.13,
      solarIndex: 1.55,
      windIndex: 1.0,
      landPrice: 12000,
      priceIndex: 1.1,
      threatIndex: 1.2,
      premium: true,
      blurb: 'The highest irradiance measured anywhere on earth. Nothing else '
          'comes close.',
    ),
    City(
      id: 'aswan',
      name: 'Aswan',
      country: 'Egypt',
      region: CityRegion.europe,
      latitude: 24.09,
      longitude: 32.90,
      solarIndex: 1.48,
      windIndex: 1.1,
      landPrice: 9500,
      priceIndex: 0.95,
      threatIndex: 1.35,
      premium: true,
      blurb: 'Nubian desert sun, effectively cloudless, all year round.',
    ),
    City(
      id: 'patagonia',
      name: 'Patagonia',
      country: 'Argentina',
      region: CityRegion.americas,
      latitude: -51.62,
      longitude: -69.22,
      solarIndex: 0.75,
      windIndex: 2.1,
      landPrice: 8000,
      priceIndex: 1.0,
      threatIndex: 0.9,
      premium: true,
      blurb: 'The most reliable wind on the planet, and weather to match.',
    ),
  ];

  static City byId(String id) =>
      cities.firstWhere((c) => c.id == id, orElse: () => cities.first);

  static List<City> inRegion(CityRegion region) =>
      cities.where((c) => c.region == region).toList();

  /// Cost to move an operation, before land: crating, freight and customs,
  /// scaled by how far it has to travel.
  static int haulageBetween(City from, City to) {
    final km = from.distanceTo(to);
    return 800 + (km * 1.4).round();
  }
}
