import 'package:flutter/material.dart';

import '../app/strings.dart';
import '../app/theme.dart';
import '../services/progress_service.dart';
import 'game_header.dart';
import 'ungrid_button.dart';

/// Écran de victoire.
///
/// Montre la distinction de la tentative, la progression du chapitre et les
/// récompenses débloquées, sans retarder le bouton suivant.
class LevelCompleteOverlay extends StatefulWidget {
  const LevelCompleteOverlay({
    super.key,
    required this.movesUsed,
    required this.elapsed,
    required this.records,
    required this.onNext,
    required this.onReplay,
    required this.allowTapAnywhere,
    this.nextLabel,
    this.mastered = false,
    this.chapter,
    this.chapterCleared = 0,
  });

  final int movesUsed;
  final Duration elapsed;
  final RecordsBeaten records;

  final VoidCallback onNext;
  final VoidCallback onReplay;
  final bool allowTapAnywhere;
  final String? nextLabel;
  final bool mastered;
  final int? chapter;
  final int chapterCleared;

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

  String? _recordLabel(Strings strings) {
    if (widget.records.both) return strings.doubleRecord;
    if (widget.records.time) return strings.newBestTime;
    if (widget.records.moves) return strings.newBestMoves;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final strings = Strings.of(context);
    final record = _recordLabel(strings);

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
            Text(
              widget.mastered ? strings.mastered : strings.solved,
              style: textTheme.displayLarge,
            ),
            const SizedBox(height: 10),
            Text(
              widget.mastered
                  ? strings.masteryRule
                  : strings.clearedWithHelp,
              style: textTheme.bodyMedium,
            ),
            if (record != null) ...[
              const SizedBox(height: 10),
              _Badge(label: record, color: UngridColors.accent),
            ],
            if (widget.chapter != null) ...[
              const SizedBox(height: 24),
              Text(
                '${strings.chapter(widget.chapter!)} '
                '· ${widget.chapterCleared}/10',
                style: textTheme.labelLarge,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 220,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: widget.chapterCleared / 10),
                  duration: const Duration(milliseconds: 650),
                  builder: (_, value, _) => LinearProgressIndicator(
                    value: value,
                    color: UngridColors.success,
                    backgroundColor: UngridColors.surface,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.chapterCleared == 10
                    ? strings.medalCollected
                    : strings.levelsToMedal(10 - widget.chapterCleared),
                style: textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Stat(label: strings.time, value: formatPlayTime(widget.elapsed)),
                const SizedBox(width: 44),
                _Stat(label: strings.moves, value: '${widget.movesUsed}'),
              ],
            ),
            const SizedBox(height: 46),
            UngridButton(
              label: widget.nextLabel ?? strings.next,
              onPressed: widget.onNext,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.onReplay,
              child: Text(strings.replay, style: textTheme.labelLarge),
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
