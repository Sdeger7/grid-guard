import 'package:flutter/foundation.dart';

/// A Data Center workload: what the facility processes. Higher-value data pays
/// more and, realistically, draws a bigger target — more energy AND more heat
/// (raids come more often and harder). This is the core risk/reward dial.
@immutable
class DcWorkload {
  const DcWorkload({
    required this.name,
    required this.emoji,
    required this.income,
    required this.draw,
    required this.threat,
    required this.requiredSecurity,
    required this.blurb,
    this.minesCoins = false,
  });

  /// Crypto workloads mint the game's own coin alongside their cash income —
  /// coins are the permanent currency that buys premium packages.
  final bool minesCoins;

  final String name;
  final String emoji;

  /// Minimum base security rating needed to accept this contract. You can't
  /// store bank/government data without enough defences in place.
  final int requiredSecurity;

  /// Base money per second while powered (before DC-level scaling).
  final double income;

  /// Base energy drawn per second (before DC-level scaling).
  final double draw;

  /// Threat factor: scales raid frequency and size. 1.0 == baseline.
  final double threat;

  final String blurb;
}

/// The selectable workloads, from safe/low-value to lucrative/high-heat.
class DcWorkloadCatalog {
  static const List<DcWorkload> workloads = [
    DcWorkload(
      name: 'Web Hosting',
      emoji: '🌐',
      income: 4,
      draw: 2,
      threat: 0.6,
      requiredSecurity: 0,
      blurb: 'Cheap, steady, barely a target.',
    ),
    DcWorkload(
      name: 'AI Compute',
      emoji: '🧠',
      income: 9,
      draw: 7,
      threat: 1.0,
      requiredSecurity: 3,
      blurb: 'Great pay, very power-hungry.',
    ),
    DcWorkload(
      name: 'Crypto Mining',
      emoji: '⛏️',
      income: 11,
      draw: 8,
      threat: 1.3,
      requiredSecurity: 6,
      blurb: 'Mints COIN — and a known target.',
      minesCoins: true,
    ),
    DcWorkload(
      name: 'Bank Records',
      emoji: '🏦',
      income: 14,
      draw: 5,
      threat: 1.6,
      requiredSecurity: 10,
      blurb: 'High-value data — strict security required.',
    ),
    DcWorkload(
      name: 'Gov Secrets',
      emoji: '🕵️',
      income: 18,
      draw: 6,
      threat: 2.3,
      requiredSecurity: 16,
      blurb: 'Maximum income, maximum heat.',
    ),
  ];
}
