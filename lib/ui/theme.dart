import 'package:flutter/material.dart';

/// Industrial-dashboard palette shared across the Flutter UI. Kept minimal and
/// high-contrast; accents are the same blue/orange the in-world neon uses.
class GGColors {
  static const bg = Color(0xFFF7F9FC);
  static const panel = Color(0xFFFFFFFF);
  static const panelBorder = Color(0xFFD7DEE8);
  static const ink = Color(0xFF1C2530);
  static const inkSoft = Color(0xFF5A6675);
  static const accent = Color(0xFF2E7DF6);
  static const accentWarm = Color(0xFFF2762E);
  static const good = Color(0xFF19B36B);
  static const teal = Color(0xFF00C2A8);
  static const danger = Color(0xFFE23D4B);
  static const mw = Color(0xFF2E7DF6);
  static const star = Color(0xFFF5B301);
  static const amber = Color(0xFFE09B12);
}

class GGText {
  static const title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: GGColors.ink,
    letterSpacing: 0.2,
  );
  static const heading = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: GGColors.ink,
  );
  static const body = TextStyle(fontSize: 14, color: GGColors.ink);
  static const soft = TextStyle(fontSize: 12, color: GGColors.inkSoft);
  static const stat = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: GGColors.ink,
  );
}

/// A sharp-edged panel — the base building block of the dashboard look.
class GGPanel extends StatelessWidget {
  const GGPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.color = GGColors.panel,
    this.borderColor = GGColors.panelBorder,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}

/// The WATT mark: a struck-through C, the same shape language as a currency
/// glyph without borrowing Bitcoin's B — this is our own closed currency and
/// should not read as somebody else's.
class WattIcon extends StatelessWidget {
  const WattIcon({super.key, this.size = 16, this.color = GGColors.amber});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          '₵',
          style: TextStyle(
            fontSize: size,
            height: 1,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ),
    );
  }
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: GGColors.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: GGColors.accent),
    fontFamily: 'Roboto',
  );
}
