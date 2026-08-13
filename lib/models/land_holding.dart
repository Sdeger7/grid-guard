import 'dart:convert';

import 'package:flutter/foundation.dart';

/// How a plot is held.
enum Tenure {
  /// Cheap to take, billed every day, and you never own it. The way most
  /// operations actually start.
  rented,

  /// Paid for outright. No recurring bill, and most of it comes back when you
  /// sell — but the capital is tied up in dirt rather than in panels.
  owned,
}

/// A plot the player holds, whether or not the site is currently standing on
/// it. Holding land in several places is the point: a site in Chile is
/// generating while a site in Türkiye is dark, and one can carry the other if
/// you are willing to pay to move the power.
@immutable
class LandHolding {
  const LandHolding({
    required this.cityId,
    required this.tenure,
    required this.acquiredAtMs,
    this.development = 0,
  });

  final String cityId;
  final Tenure tenure;
  final int acquiredAtMs;

  /// How built-out a plot is while you are not standing on it, in whole units
  /// of invested capital. Background plots earn from this rather than from
  /// individual structures — the detailed simulation only runs where you are.
  final int development;

  LandHolding copyWith({Tenure? tenure, int? development}) => LandHolding(
        cityId: cityId,
        tenure: tenure ?? this.tenure,
        acquiredAtMs: acquiredAtMs,
        development: development ?? this.development,
      );

  Map<String, dynamic> toJson() => {
        'c': cityId,
        't': tenure.name,
        'a': acquiredAtMs,
        'd': development,
      };

  static LandHolding fromJson(Map<String, dynamic> j) => LandHolding(
        cityId: j['c'] as String,
        tenure: Tenure.values.firstWhere(
          (t) => t.name == j['t'],
          orElse: () => Tenure.rented,
        ),
        acquiredAtMs: (j['a'] as num?)?.toInt() ?? 0,
        development: (j['d'] as num?)?.toInt() ?? 0,
      );

  static String encodeAll(List<LandHolding> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<LandHolding> decodeAll(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => LandHolding.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
