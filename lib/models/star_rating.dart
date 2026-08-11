import 'package:flutter/foundation.dart';

/// The three-star result of a level attempt. The stars are independent:
/// [survived] is the win condition; the other two are performance goals.
@immutable
class StarRating {
  const StarRating({
    required this.survived,
    required this.lowDamage,
    required this.fastEnough,
  });

  /// Star 1 — cleared all waves with the core alive.
  final bool survived;

  /// Star 2 — took at most the level's damage threshold.
  final bool lowDamage;

  /// Star 3 — finished within the level's time threshold.
  final bool fastEnough;

  static const StarRating none =
      StarRating(survived: false, lowDamage: false, fastEnough: false);

  int get count =>
      (survived ? 1 : 0) + (lowDamage ? 1 : 0) + (fastEnough ? 1 : 0);

  bool get isWin => survived;

  /// Merge with a previous best, keeping the best of each star.
  StarRating mergeBest(StarRating other) => StarRating(
        survived: survived || other.survived,
        lowDamage: lowDamage || other.lowDamage,
        fastEnough: fastEnough || other.fastEnough,
      );

  factory StarRating.fromCount(int count) => StarRating(
        survived: count >= 1,
        lowDamage: count >= 2,
        fastEnough: count >= 3,
      );
}
