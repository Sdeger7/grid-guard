import 'package:flutter/material.dart';

import '../../data/abilities.dart';
import '../../game/grid_guard_game.dart';
import '../theme.dart';

/// The operator's controls, sitting just above the build tray.
///
/// Towers fire themselves, so this row is the difference between watching a
/// raid and fighting one. Each button shows its cooldown as a sweep of dead
/// space, so the state of every ability is readable at a glance mid-raid.
class AbilityBar extends StatelessWidget {
  const AbilityBar({super.key, required this.game, required this.onUsed});

  final GridGuardGame game;
  final VoidCallback onUsed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final a in AbilityCatalog.all)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _AbilityButton(
                ability: a,
                active: game.isAbilityActive(a.kind),
                cooldownLeft: game.cooldownLeft(a.kind),
                onTap: () {
                  if (game.useAbility(a.kind)) onUsed();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AbilityButton extends StatelessWidget {
  const _AbilityButton({
    required this.ability,
    required this.active,
    required this.cooldownLeft,
    required this.onTap,
  });

  final Ability ability;
  final bool active;
  final double cooldownLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ready = cooldownLeft <= 0 && !active;
    final fraction =
        ability.cooldown <= 0 ? 0.0 : (cooldownLeft / ability.cooldown).clamp(0.0, 1.0);

    return Tooltip(
      message: '${ability.name}\n${ability.blurb}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: ready ? onTap : null,
        child: Opacity(
          opacity: ready ? 1.0 : 0.55,
          child: SizedBox(
            width: 62,
            child: GGPanel(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              borderColor: active
                  ? GGColors.accent
                  : ready
                      ? GGColors.panelBorder
                      : GGColors.inkSoft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(ability.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 2),
                  Text(
                    active
                        ? 'ON'
                        : ready
                            ? ability.name.split(' ').first.toUpperCase()
                            : '${cooldownLeft.ceil()}s',
                    style: GGText.soft.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: active ? GGColors.accent : GGColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: active ? 1.0 : 1 - fraction,
                      minHeight: 3,
                      backgroundColor: GGColors.panelBorder,
                      valueColor: AlwaysStoppedAnimation(
                          active ? GGColors.accent : GGColors.good),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
