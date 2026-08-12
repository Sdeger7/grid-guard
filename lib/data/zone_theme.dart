import 'package:flutter/material.dart';

/// Per-zone palette. The visual language stays minimalist/industrial across all
/// zones; only accent temperature shifts — cool industrial blue in Zone 1
/// drifting toward critical-load orange/red by Zone 5.
@immutable
class ZoneTheme {
  const ZoneTheme({
    required this.name,
    required this.ground,
    required this.groundAlt,
    required this.accent,
    required this.conduit,
  });

  final String name;

  /// Two alternating ground-tile shades for a subtle checker.
  final Color ground;
  final Color groundAlt;

  /// Neon accent for HUD lines and structure highlights.
  final Color accent;

  /// Conduit line colour.
  final Color conduit;

  /// Grass tones per zone — greener/lusher early, drier and scorched deeper in.
  static const List<ZoneTheme> zones = [
    ZoneTheme(
      name: 'Zone 1 · Grid Perimeter',
      ground: Color(0xFF6DAB52),
      groundAlt: Color(0xFF5F9B47),
      accent: Color(0xFF2E7DF6),
      conduit: Color(0xFF57A0FF),
    ),
    ZoneTheme(
      name: 'Zone 2 · Substation Ring',
      ground: Color(0xFF6BA84F),
      groundAlt: Color(0xFF5C9644),
      accent: Color(0xFF19A7C4),
      conduit: Color(0xFF3FC7E0),
    ),
    ZoneTheme(
      name: 'Zone 3 · Core Approach',
      ground: Color(0xFF7CA84C),
      groundAlt: Color(0xFF6C9642),
      accent: Color(0xFFF2A93B),
      conduit: Color(0xFFFFC46B),
    ),
    ZoneTheme(
      name: 'Zone 4 · Overload District',
      ground: Color(0xFF8CA349),
      groundAlt: Color(0xFF7B913F),
      accent: Color(0xFFF2762E),
      conduit: Color(0xFFFF9A5A),
    ),
    ZoneTheme(
      name: 'Zone 5 · Critical Load',
      ground: Color(0xFF97984A),
      groundAlt: Color(0xFF868740),
      accent: Color(0xFFE23D4B),
      conduit: Color(0xFFFF6A78),
    ),
  ];

  /// [zone] is 1-based.
  static ZoneTheme forZone(int zone) => zones[(zone - 1).clamp(0, 4)];
}
