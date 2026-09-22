import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../services/progress_service.dart';
import 'game_header.dart';
import 'ungrid_button.dart';

/// Écran de victoire.
///
/// Il dit l'essentiel — le temps, les coups — et s'efface. Pas de score, pas
/// d'étoiles : terminer dans la limite, c'est gagné, point. Le reste n'est là
/// que pour donner envie de refaire mieux.
class LevelCompleteOverlay extends StatefulWidget {
  const LevelCompleteOverlay({
    super.key,
    required this.movesUsed,
    required this.elapsed,
    required this.records,
    required this.onNext,
    required this.onReplay,
    required this.allowTapAnywhere,
  });

  final int movesUsed;
  final Duration elapsed;
  final RecordsBeaten records;

  final VoidCallback onNext;
  final VoidCallback onReplay;
  final bool allowTapAnywhere;

  @override
  State<LevelCompleteOverlay> createState() => _LevelCompleteOverlayState();
}

class _LevelCompleteOverlayState extends State<LevelCompleteOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  String? get _recordLabel {
    if (widget.records.both) return 'DOUBLE RECORD';
    if (widget.records.time) return 'NEW BEST TIME';
    if (widget.records.moves) return 'NEW BEST MOVES';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final record = _recordLabel;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.allowTapAnywhere ? widget.onNext : null,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final entrance = Curves.easeOutCubic.transform(_animation.value);
          return Opacity(
            opacity: entrance,
            child: Container(
              color: UngridColors.background.withValues(alpha: 0.97),
              child: Center(
                child: Transform.translate(
                  offset: Offset(0, (1 - entrance) * 18),
                  child: child,
                ),
              ),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('CLEAR', style: textTheme.displayLarge),
            if (record != null) ...[
              const SizedBox(height: 10),
              _Badge(label: record, color: UngridColors.accent),
            ],
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Stat(
                  label: 'TIME',
                  value: formatPlayTime(widget.elapsed),
                ),
                const SizedBox(width: 44),
                _Stat(label: 'MOVES', value: '${widget.movesUsed}'),
              ],
            ),
            const SizedBox(height: 46),
            UngridButton(label: 'NEXT', onPressed: widget.onNext),
            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.onReplay,
              child: Text('REPLAY', style: textTheme.labelLarge),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: UngridColors.onBackground,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: UngridColors.arrow,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}
