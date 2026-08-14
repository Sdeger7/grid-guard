/// Plain-text stand-in for `WattIcon` inside interpolated strings, where a
/// real widget can't go. Two glyphs, not one — there is no single Unicode
/// character for "bolt over a W" — but it still reads as one mark and never
/// collides with the Credits symbol below.
const String wattSymbol = '⚡W';

/// Cash, in the site's own currency. Written with a completely different
/// mark from WATT (₡ vs ⚡W) so the two can never be misread for each other,
/// however similar the numbers next to them get.
const String creditsSymbol = '₡';

/// Formats a Credits amount: the ₡ symbol plus the number, abbreviated to
/// K/M/B once it grows past four digits so a built-out site's numbers stay
/// readable instead of running to nine digits. Negative values keep their
/// own '-'; callers that want an explicit '+' for positive values add it
/// themselves in front of the result.
String formatCredits(num value) {
  final v = value.toDouble();
  final neg = v < 0;
  final abs = v.abs();
  String body;
  if (abs >= 1e9) {
    body = '${(abs / 1e9).toStringAsFixed(abs >= 1e10 ? 1 : 2)}B';
  } else if (abs >= 1e6) {
    body = '${(abs / 1e6).toStringAsFixed(abs >= 1e7 ? 1 : 2)}M';
  } else if (abs >= 1e3) {
    body = '${(abs / 1e3).toStringAsFixed(abs >= 1e4 ? 1 : 2)}K';
  } else {
    // Sub-thousand values can be unit prices (0.36 credits per unit of
    // energy, say) as easily as round totals — keep the decimals unless
    // there genuinely aren't any.
    body = abs == abs.roundToDouble()
        ? abs.toStringAsFixed(0)
        : abs.toStringAsFixed(2);
  }
  return '${neg ? '-' : ''}$creditsSymbol$body';
}

/// [formatCredits] with an explicit sign and a trailing rate unit, for the
/// per-hour/per-second figures scattered through the HUD and reports.
String formatCreditsRate(num value, {String suffix = '/h'}) =>
    '${value >= 0 ? '+' : ''}${formatCredits(value)}$suffix';
