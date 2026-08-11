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

  static const List<ZoneTheme> zones = [
    ZoneTheme(
      name: 'Zone 1 · Grid Perimeter',
      ground: Color(0xFFEDF1F5),
      groundAlt: Color(0xFFE1E7EE),
      accent: Color(0xFF2E7DF6),
      conduit: Color(0xFF57A0FF),
    ),
    ZoneTheme(
      name: 'Zone 2 · Substation Ring',
      ground: Color(0xFFEDF0F3),
      groundAlt: Color(0xFFDFE4EA),
      accent: Color(0xFF19A7C4),
      conduit: Color(0xFF3FC7E0),
    ),
    ZoneTheme(
      name: 'Zone 3 · Core Approach',
      ground: Color(0xFFF3EFEA),
      groundAlt: Color(0xFFE9E1D8),
      accent: Color(0xFFF2A93B),
      conduit: Color(0xFFFFC46B),
    ),
    ZoneTheme(
      name: 'Zone 4 · Overload District',
      ground: Color(0xFFF4EAE6),
      groundAlt: Color(0xFFEAD9D2),
      accent: Color(0xFFF2762E),
      conduit: Color(0xFFFF9A5A),
    ),
    ZoneTheme(
      name: 'Zone 5 · Critical Load',
      ground: Color(0xFFF4E7E6),
      groundAlt: Color(0xFFE9D3D2),
      accent: Color(0xFFE23D4B),
      conduit: Color(0xFFFF6A78),
    ),
  ];

  /// [zone] is 1-based.
  static ZoneTheme forZone(int zone) => zones[(zone - 1).clamp(0, 4)];
}
