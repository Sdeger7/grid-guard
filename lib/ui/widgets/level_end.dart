import 'package:flutter/material.dart';

import '../../models/level_state.dart';
import '../theme.dart';
import 'star_row.dart';

/// Victory panel. Shows stars and rewards, offers a one-tap "2x reward"
/// rewarded-ad, and advances. The double-reward flow is wired to the
/// MonetizationService via [onWatchDoubleReward] (returns whether reward was
/// earned); the parent applies the currency change.
class WinPanel extends StatefulWidget {
  const WinPanel({
    super.key,
    required this.result,
    required this.onWatchDoubleReward,
    required this.onNext,
    required this.onMenu,
  });

  final LevelResult result;

  /// Resolves true if the rewarded ad completed; the panel then reflects the
  /// doubled credits.
  final Future<bool> Function() onWatchDoubleReward;
  final VoidCallback onNext;
  final VoidCallback onMenu;

  @override
  State<WinPanel> createState() => _WinPanelState();
}

class _WinPanelState extends State<WinPanel> {
  bool _doubled = false;
  bool _busy = false;

  int get _credits =>
      _doubled ? widget.result.baseGridCredits * 2 : widget.result.baseGridCredits;

  Future<void> _watch() async {
    setState(() => _busy = true);
    final earned = await widget.onWatchDoubleReward();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (earned) _doubled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return _Scrim(
      child: GGPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('GRID SECURED', style: GGText.title),
            const SizedBox(height: 12),
            StarRow(filled: r.stars.count, size: 34),
            const SizedBox(height: 16),
            _RewardRow(
                label: 'Grid Credits',
                value: '+$_credits',
                highlight: _doubled),
            _RewardRow(label: 'Score', value: '${r.finalScore}'),
            _RewardRow(
                label: 'Time', value: '${r.timeSeconds.toStringAsFixed(1)}s'),
            const SizedBox(height: 16),
            if (!_doubled)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _watch,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_circle_fill_rounded),
                  label: const Text('Watch ad for 2× reward'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GGColors.accentWarm,
                    side: const BorderSide(color: GGColors.accentWarm),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: widget.onMenu,
                    child: const Text('Level Select'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GGColors.good,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Next Level'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Defeat panel. Offers a one-time rewarded-ad "Continue" (revive) and a retry.
class LosePanel extends StatefulWidget {
  const LosePanel({
    super.key,
    required this.canContinue,
    required this.onContinue,
    required this.onRetry,
    required this.onMenu,
  });

  /// False once the per-level continue has been used.
  final bool canContinue;

  /// Resolves true if the rewarded ad completed and the run should resume.
  final Future<bool> Function() onContinue;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  @override
  State<LosePanel> createState() => _LosePanelState();
}

class _LosePanelState extends State<LosePanel> {
  bool _busy = false;

  Future<void> _continue() async {
    setState(() => _busy = true);
    final ok = await widget.onContinue();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad not completed — no revive.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Scrim(
      child: GGPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('CORE BREACHED', style: GGText.title),
            const SizedBox(height: 6),
            const Text('The BESS 1M went dark.', style: GGText.soft),
            const SizedBox(height: 16),
            if (widget.canContinue)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _continue,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_circle_fill_rounded),
                  label: const Text('Continue (watch ad)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GGColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: widget.onMenu,
                    child: const Text('Level Select'),
                  ),
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onRetry,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow(
      {required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GGText.soft),
          Text(value,
              style: GGText.stat.copyWith(
                  color: highlight ? GGColors.accentWarm : GGColors.ink)),
        ],
      ),
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      ),
    );
  }
}
