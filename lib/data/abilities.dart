import 'package:flutter/foundation.dart';

/// The operator's own controls.
enum AbilityKind {
  /// Dump the battery into the transformers: double damage, double the energy
  /// cost per shot, for a short burst.
  overcharge,

  /// Cut the Data Centers dead. No income, no draw — every joule goes to
  /// keeping the guns firing.
  shutdown,

  /// Kill every light and emitter on site. Raiders lose their targets and
  /// wander until it comes back up.
  blackout,

  /// Scramble the maintenance crew: an immediate partial repair across
  /// everything damaged, paid for in energy rather than cash.
  crew,
}

/// A manual ability: the part of a night the player actually plays.
///
/// Towers fire themselves, so without these a raid is something you watch. Each
/// one is a real trade — power, income, or safety spent against a moment of
/// pressure — and each has a long enough cooldown that using it early is a
/// decision you can regret.
@immutable
class Ability {
  const Ability({
    required this.kind,
    required this.name,
    required this.emoji,
    required this.duration,
    required this.cooldown,
    required this.blurb,
    required this.shortName,
  });

  final AbilityKind kind;
  final String name;
  final String emoji;

  /// Four or five characters, for the button face — full names wrap badly on a
  /// phone-sized button.
  final String shortName;

  /// Seconds the effect lasts. Zero for instant abilities.
  final double duration;

  /// Seconds before it can be used again.
  final double cooldown;

  final String blurb;
}

class AbilityCatalog {
  static const List<Ability> all = [
    Ability(
      kind: AbilityKind.overcharge,
      name: 'Overcharge',
      shortName: 'BOOST',
      emoji: '⚡',
      duration: 20,
      cooldown: 120,
      blurb: 'Transformers hit twice as hard and burn twice the energy.',
    ),
    Ability(
      kind: AbilityKind.shutdown,
      name: 'Emergency Stop',
      shortName: 'STOP',
      emoji: '⏹️',
      duration: 30,
      cooldown: 90,
      blurb: 'Data Centers go dark. No income, no draw, all power to defence.',
    ),
    Ability(
      kind: AbilityKind.blackout,
      name: 'Go Dark',
      shortName: 'DARK',
      emoji: '🌑',
      duration: 10,
      cooldown: 150,
      blurb: 'Kill the lights. Raiders lose their targets and scatter.',
    ),
    Ability(
      kind: AbilityKind.crew,
      name: 'Crew Callout',
      shortName: 'CREW',
      emoji: '🔧',
      duration: 0,
      cooldown: 180,
      blurb: 'Patch every damaged structure by 30%, paid in energy.',
    ),
  ];

  static Ability of(AbilityKind kind) =>
      all.firstWhere((a) => a.kind == kind);
}
