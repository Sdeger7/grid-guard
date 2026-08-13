import 'dart:math' as math;

/// Where the sun actually is.
///
/// The site runs on the player's own clock and their own latitude, so a panel
/// in Konya in June behaves like a panel in Konya in June: up before six, sixty
/// degrees at noon, still working at eight in the evening. In December the same
/// panel gets nine hours of weak, low-angle light and the player finds out
/// exactly why storage matters. Nothing here needs a network — it is the same
/// astronomy every solar calculator uses.
class SolarPosition {
  const SolarPosition({
    required this.elevationDegrees,
    required this.clearSkyFactor,
    required this.sunrise,
    required this.sunset,
    required this.dayLengthHours,
  });

  /// Sun height above the horizon. Negative means night.
  final double elevationDegrees;

  /// Irradiance factor in [0,1] for a clear sky: what a panel would make right
  /// now with no cloud. Combines the sun's height with the thicker atmosphere
  /// it shines through at low angles.
  final double clearSkyFactor;

  final DateTime sunrise;
  final DateTime sunset;
  final double dayLengthHours;

  bool get isDay => elevationDegrees > 0;
}

class SolarMath {
  /// Solar position for [when] at [latitude]/[longitude], in local time.
  static SolarPosition at({
    required double latitude,
    required double longitude,
    DateTime? when,
  }) {
    final t = when ?? DateTime.now();
    final dayOfYear = _dayOfYear(t);

    // Declination: the sun's tilt, which is where every seasonal effect in the
    // game ultimately comes from.
    final decl = 23.45 *
        math.sin(_rad(360 * (284 + dayOfYear) / 365));

    // Solar noon drifts from clock noon by the equation of time and by how far
    // the site sits from the centre of its time zone.
    final b = _rad(360 * (dayOfYear - 81) / 364);
    final eot = 9.87 * math.sin(2 * b) - 7.53 * math.cos(b) - 1.5 * math.sin(b);
    final tzOffsetHours = t.timeZoneOffset.inMinutes / 60.0;
    final standardMeridian = 15.0 * tzOffsetHours;
    final correctionMinutes = 4 * (longitude - standardMeridian) + eot;

    final localMinutes = t.hour * 60.0 + t.minute + t.second / 60.0;
    final solarMinutes = localMinutes + correctionMinutes;
    final hourAngle = (solarMinutes / 4.0) - 180.0;

    final latRad = _rad(latitude);
    final declRad = _rad(decl);
    final haRad = _rad(hourAngle);

    final sinElevation = math.sin(latRad) * math.sin(declRad) +
        math.cos(latRad) * math.cos(declRad) * math.cos(haRad);
    final elevation = _deg(math.asin(sinElevation.clamp(-1.0, 1.0)));

    // Air mass: light through a shallow angle crosses more atmosphere and
    // arrives weaker, which is why winter output is worse than day length
    // alone suggests.
    double clearSky = 0;
    if (elevation > 0) {
      final airMass = 1 / (sinElevation + 0.50572 * math.pow(elevation + 6.07995, -1.6364));
      clearSky = (math.pow(0.7, math.pow(airMass, 0.678)) * sinElevation)
          .toDouble()
          .clamp(0.0, 1.0);
    }

    // Sunrise/sunset from the hour angle where the sun crosses the horizon.
    final cosHourAngle =
        (-math.tan(latRad) * math.tan(declRad)).clamp(-1.0, 1.0);
    final halfDayHours = _deg(math.acos(cosHourAngle)) / 15.0;
    final solarNoonMinutes = 720 - correctionMinutes;
    final midnight = DateTime(t.year, t.month, t.day);
    final sunrise = midnight.add(Duration(
        minutes: (solarNoonMinutes - halfDayHours * 60).round()));
    final sunset = midnight.add(Duration(
        minutes: (solarNoonMinutes + halfDayHours * 60).round()));

    return SolarPosition(
      elevationDegrees: elevation,
      clearSkyFactor: clearSky,
      sunrise: sunrise,
      sunset: sunset,
      dayLengthHours: halfDayHours * 2,
    );
  }

  static int _dayOfYear(DateTime t) =>
      t.difference(DateTime(t.year, 1, 1)).inDays + 1;

  static double _rad(double deg) => deg * math.pi / 180.0;
  static double _deg(double rad) => rad * 180.0 / math.pi;
}
