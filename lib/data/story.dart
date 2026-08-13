import 'package:flutter/foundation.dart';

/// One story beat, delivered at dawn. Beats are the connective tissue between
/// nights: they explain who is attacking, why the contracts keep getting more
/// dangerous, and what the operator is actually building toward.
@immutable
class StoryBeat {
  const StoryBeat({
    required this.day,
    required this.from,
    required this.title,
    required this.body,
  });

  /// The day this beat arrives on (dawn of that day).
  final int day;

  /// Who sent it — the message is framed as traffic across the operator's link.
  final String from;

  final String title;
  final String body;
}

/// The arc: an off-grid operator keeps a data center alive in a blackout zone,
/// discovers the raids are contracted rather than random, and has to decide how
/// far up the value chain to climb.
class StoryCatalog {
  static const List<StoryBeat> beats = [
    StoryBeat(
      day: 2,
      from: 'SITE LOG',
      title: 'First night survived',
      body: 'The grid held. Whatever those drones were, they went for the '
          'hardware, not the fence — someone wanted downtime, not theft. '
          'Keep the battery charged and keep building.',
    ),
    StoryBeat(
      day: 3,
      from: 'MERIDIAN HOSTING',
      title: 'Your uptime is showing',
      body: 'You are the only site in the zone still answering. We are moving '
          'more load to you. Pay goes up. So does the attention.',
    ),
    StoryBeat(
      day: 5,
      from: 'UNKNOWN',
      title: 'Stop taking their work',
      body: 'A single line, no signature, routed through three relays. Then '
          'the sky filled up. They are not raiders. Somebody is paying them '
          'by the hour.',
    ),
    StoryBeat(
      day: 7,
      from: 'SITE LOG',
      title: 'Salvage tells a story',
      body: 'The wrecks carry utility-issue transponders with the plates '
          'ground off. The people who cut the power to this zone are the same '
          'people billing to keep it dark.',
    ),
    StoryBeat(
      day: 9,
      from: 'BROKER',
      title: 'Crypto contract cleared',
      body: 'Mining pays in coin nobody can freeze — which is exactly why the '
          'raids get louder when you run it. Bank it. You will want leverage '
          'later.',
    ),
    StoryBeat(
      day: 12,
      from: 'ARCLIGHT TRUST',
      title: 'We need somewhere off the books',
      body: 'Bank records. Real money, real security floor. If your site goes '
          'dark with our data on it, neither of us has a second conversation.',
    ),
    StoryBeat(
      day: 15,
      from: 'UNKNOWN',
      title: 'Last warning',
      body: 'They stopped hiring subcontractors. What comes tonight is their '
          'own equipment, and it is not built to be scared off.',
    ),
    StoryBeat(
      day: 18,
      from: 'MINISTRY LIAISON',
      title: 'The quiet contract',
      body: 'Everything above this line was deniable. This is not. Run our '
          'traffic and the zone stays yours — assuming there is a zone left '
          'by the time we finish talking.',
    ),
    StoryBeat(
      day: 21,
      from: 'SITE LOG',
      title: 'Lights on, three weeks',
      body: 'Twenty-one nights. The zone map now draws your site as permanent '
          'infrastructure. Every night from here is one nobody has held '
          'before.',
    ),
  ];

  /// The beat for [day], or null if nothing happens that morning.
  static StoryBeat? forDay(int day) {
    for (final b in beats) {
      if (b.day == day) return b;
    }
    return null;
  }
}
