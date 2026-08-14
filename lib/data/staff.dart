import 'dart:math' as math;

/// The site's crew: three roles that get better at their job the longer they
/// do it. There is no hiring screen and no wage — they are already on-site,
/// and they level up simply by the plant staying open, which is the whole
/// point: growth that rewards a run that keeps running, not one more thing
/// to shop for.
enum StaffRole {
  engineer('Chief Engineer', '🛠️', 'Maintenance and equipment condition'),
  security('Security Chief', '🕵️', 'Firewall strength and breach frequency'),
  sales('Sales Lead', '💼', 'Contract income and grid prices');

  const StaffRole(this.title, this.emoji, this.domain);

  final String title;
  final String emoji;
  final String domain;
}

class StaffMember {
  StaffMember(this.role, {this.xp = 0});

  final StaffRole role;
  double xp;

  static const int maxLevel = 10;

  /// XP needed to reach a given level from zero, cumulative. Climbs faster
  /// each level so the early ranks — where the bonus first becomes visible —
  /// come quickly, and the last one or two are a real achievement.
  static double xpForLevel(int level) {
    var total = 0.0;
    for (var l = 1; l < level; l++) {
      total += 40.0 * math.pow(l, 1.35);
    }
    return total;
  }

  int get level {
    var lvl = 1;
    while (lvl < maxLevel && xp >= xpForLevel(lvl + 1)) {
      lvl++;
    }
    return lvl;
  }

  /// Progress toward the next level, in [0,1]. Pinned at 1 once maxed.
  double get levelProgress {
    if (level >= maxLevel) return 1;
    final base = xpForLevel(level);
    final next = xpForLevel(level + 1);
    if (next <= base) return 1;
    return ((xp - base) / (next - base)).clamp(0.0, 1.0);
  }

  /// Fraction applied per level, before role-specific interpretation.
  double get _rank => (level - 1) / (maxLevel - 1);

  // ---- Engineer ----
  /// Multiplies [GridGuardGame.operatingCost]: up to 25% off at max level.
  double get upkeepMultiplier =>
      role == StaffRole.engineer ? 1 - _rank * 0.25 : 1;

  /// Multiplies solar/wind/BESS nameplate output: up to +18% at max level.
  double get outputMultiplier =>
      role == StaffRole.engineer ? 1 + _rank * 0.18 : 1;

  // ---- Security ----
  /// Added straight onto firewall resistance, still capped below 100%
  /// wherever that resistance is spent.
  double get resistanceBonus => role == StaffRole.security ? _rank * 0.12 : 0;

  /// Multiplies how often intrusions are attempted: down to -35% at max.
  double get intrusionFrequencyMultiplier =>
      role == StaffRole.security ? 1 - _rank * 0.35 : 1;

  // ---- Sales ----
  /// Multiplies Data Center income: up to +22% at max level.
  double get incomeMultiplier => role == StaffRole.sales ? 1 + _rank * 0.22 : 1;

  /// Multiplies the price fetched on grid exports/sell contracts: up to
  /// +10% at max level — a sharper negotiator gets a better rate.
  double get gridPriceMultiplier =>
      role == StaffRole.sales ? 1 + _rank * 0.10 : 1;
}

/// The crew, indexed by role. Always exactly one member per role.
class StaffRoster {
  StaffRoster({Map<StaffRole, double>? xp})
      : members = {
          for (final role in StaffRole.values)
            role: StaffMember(role, xp: xp?[role] ?? 0),
        };

  final Map<StaffRole, StaffMember> members;

  StaffMember of(StaffRole role) => members[role]!;

  /// XP earned per second the site is open, split evenly across the crew —
  /// everyone is on the clock at once.
  static const double xpPerSecond = 1.0;

  void tick(double dt) {
    for (final m in members.values) {
      if (m.level >= StaffMember.maxLevel) continue;
      m.xp += xpPerSecond * dt;
    }
  }

  Map<String, double> toJson() =>
      {for (final e in members.entries) e.key.name: e.value.xp};

  static StaffRoster fromJson(Map<String, dynamic>? j) {
    if (j == null) return StaffRoster();
    final xp = <StaffRole, double>{};
    for (final role in StaffRole.values) {
      final v = j[role.name];
      if (v is num) xp[role] = v.toDouble();
    }
    return StaffRoster(xp: xp);
  }
}
