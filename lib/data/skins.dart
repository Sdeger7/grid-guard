import 'package:flutter/material.dart';

/// What a skin re-dresses.
enum SkinSlot {
  /// Your interceptor drones.
  drone,

  /// Every built structure on the site.
  structure,

  /// The ground itself.
  terrain,
}

/// A cosmetic set.
///
/// Skins are pure paint: they change palettes and a few drawn details and touch
/// no stat anywhere. That is deliberate — the moment a skin makes a site
/// stronger, every player who did not buy it is playing a worse game.
///
/// Each carries a [spriteKey]: if art with that name ships in assets, the game
/// draws it; otherwise the palette below re-tints the procedural rendering. So
/// hand-drawn skins can be dropped in later without a line of code changing.
@immutable
class Skin {
  const Skin({
    required this.id,
    required this.slot,
    required this.name,
    required this.emoji,
    required this.blurb,
    required this.price,
    required this.primary,
    required this.secondary,
    required this.accent,
    this.spriteKey,
    this.free = false,
  });

  final String id;
  final SkinSlot slot;
  final String name;
  final String emoji;
  final String blurb;

  /// Cost in WATT. Cosmetics are the honest sink for a closed currency: they
  /// give mining a purpose without ever selling power.
  final int price;

  /// The palette the procedural renderers use.
  final Color primary;
  final Color secondary;
  final Color accent;

  /// Optional art atlas name, used when the assets are present.
  final String? spriteKey;

  /// Owned from the start.
  final bool free;
}

class SkinCatalog {
  static const List<Skin> skins = [
    // ---- Drones ----
    Skin(
      id: 'drone_default',
      slot: SkinSlot.drone,
      name: 'Field Green',
      emoji: '🟢',
      blurb: 'Standard issue. Easy to spot against grass.',
      price: 0,
      primary: Color(0xFF23D97E),
      secondary: Color(0xFF0E4F31),
      accent: Color(0xFFFFE08A),
      free: true,
    ),
    Skin(
      id: 'drone_hazard',
      slot: SkinSlot.drone,
      name: 'Hazard Stripe',
      emoji: '🟡',
      blurb: 'Utility yellow and black. Looks like it belongs on a substation.',
      price: 2,
      primary: Color(0xFFF4B740),
      secondary: Color(0xFF2A2418),
      accent: Color(0xFFFFF3C0),
    ),
    Skin(
      id: 'drone_night',
      slot: SkinSlot.drone,
      name: 'Night Patrol',
      emoji: '⚫',
      blurb: 'Matte black with a cold blue underglow.',
      price: 4,
      primary: Color(0xFF2B3444),
      secondary: Color(0xFF0B1018),
      accent: Color(0xFF5AC8FF),
    ),
    Skin(
      id: 'drone_neon',
      slot: SkinSlot.drone,
      name: 'Neon Grid',
      emoji: '🟣',
      blurb: 'Magenta shell, cyan rotors. Subtlety is not the point.',
      price: 7,
      primary: Color(0xFFE85CD8),
      secondary: Color(0xFF2A0F33),
      accent: Color(0xFF4FF0E0),
    ),
    Skin(
      id: 'drone_rust',
      slot: SkinSlot.drone,
      name: 'Salvage',
      emoji: '🟠',
      blurb: 'Built from wrecks, and it shows.',
      price: 5,
      primary: Color(0xFFB4643C),
      secondary: Color(0xFF3B2418),
      accent: Color(0xFFE0C08A),
    ),

    // ---- Structures ----
    Skin(
      id: 'struct_default',
      slot: SkinSlot.structure,
      name: 'Works Standard',
      emoji: '⚙️',
      blurb: 'Whatever the contractor had in the yard.',
      price: 0,
      primary: Color(0xFF9AA3A8),
      secondary: Color(0xFF3E4A57),
      accent: Color(0xFFFFE08A),
      free: true,
    ),
    Skin(
      id: 'struct_military',
      slot: SkinSlot.structure,
      name: 'Olive Detachment',
      emoji: '🪖',
      blurb: 'Olive drab and stencilled numbers. Nothing here is civilian.',
      price: 4,
      primary: Color(0xFF6A7A4C),
      secondary: Color(0xFF39421F),
      accent: Color(0xFFD8DFA0),
    ),
    Skin(
      id: 'struct_arctic',
      slot: SkinSlot.structure,
      name: 'Arctic Station',
      emoji: '❄️',
      blurb: 'White panels, orange trim, built for somewhere colder.',
      price: 6,
      primary: Color(0xFFE8EEF3),
      secondary: Color(0xFF8FA3B5),
      accent: Color(0xFFFF8A3D),
    ),
    Skin(
      id: 'struct_carbon',
      slot: SkinSlot.structure,
      name: 'Carbon Works',
      emoji: '🖤',
      blurb: 'Black composite and a thin green trace. Very expensive-looking.',
      price: 9,
      primary: Color(0xFF23262B),
      secondary: Color(0xFF14161A),
      accent: Color(0xFF43E08A),
    ),

    // ---- Terrain ----
    Skin(
      id: 'terrain_default',
      slot: SkinSlot.terrain,
      name: 'Meadow',
      emoji: '🌿',
      blurb: 'Green grass and quiet water.',
      price: 0,
      primary: Color(0xFF57A046),
      secondary: Color(0xFF2F5F2A),
      accent: Color(0xFF2C7DA0),
      free: true,
    ),
    Skin(
      id: 'terrain_dust',
      slot: SkinSlot.terrain,
      name: 'Dust Flats',
      emoji: '🏜️',
      blurb: 'Sun-bleached scrub and standing brine.',
      price: 3,
      primary: Color(0xFFC9A96A),
      secondary: Color(0xFF8C7040),
      accent: Color(0xFF6FA8A0),
    ),
    Skin(
      id: 'terrain_snow',
      slot: SkinSlot.terrain,
      name: 'Hard Winter',
      emoji: '🌨️',
      blurb: 'Packed snow, black ice, and very short days.',
      price: 5,
      primary: Color(0xFFE4ECF2),
      secondary: Color(0xFFA9BCCA),
      accent: Color(0xFF4E8FB8),
    ),
    Skin(
      id: 'terrain_ash',
      slot: SkinSlot.terrain,
      name: 'Ashfall',
      emoji: '🌋',
      blurb: 'Grey ground, dark water, nothing growing.',
      price: 8,
      primary: Color(0xFF6E6A6B),
      secondary: Color(0xFF44403F),
      accent: Color(0xFF7A5C4A),
    ),
  ];

  static Skin byId(String id) =>
      skins.firstWhere((s) => s.id == id, orElse: () => skins.first);

  static List<Skin> forSlot(SkinSlot slot) =>
      skins.where((s) => s.slot == slot).toList();

  /// The default (free) skin for a slot, used when nothing is equipped.
  static Skin defaultFor(SkinSlot slot) =>
      skins.firstWhere((s) => s.slot == slot && s.free);
}
