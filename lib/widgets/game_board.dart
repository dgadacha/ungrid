import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/controllers/game_controller.dart';
import '../game/painters/block_painter.dart';
import '../game/painters/board_layout.dart';
import '../game/painters/effects_painter.dart';
import '../game/painters/game_painter.dart';

/// La grille jouable.
///
/// Un seul `Ticker` alimente toutes les animations, et il ne tourne que
/// lorsqu'il y a quelque chose à animer : au repos, le jeu ne consomme rien.
/// Le dessin est isolé dans son propre calque pour que rien d'autre ne soit
/// reconstruit à chaque frame.
class GameBoard extends StatefulWidget {
  const GameBoard({super.key, required this.controller});

  final GameController controller;

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  final BlockPainter _blockPainter = BlockPainter();
  final ClearEffect _clearEffect = ClearEffect();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame);
    widget.controller.addListener(_ensureTicking);
    _ensureTicking();
  }

  @override
  void didUpdateWidget(GameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_ensureTicking);
      widget.controller.addListener(_ensureTicking);
      _ensureTicking();
    }
  }

  void _onFrame(Duration _) {
    widget.controller.pruneAnimations();
    _frame.value = widget.controller.nowMs;
    if (!widget.controller.hasActiveAnimations) _ticker.stop();
  }

  void _ensureTicking() {
    if (widget.controller.hasActiveAnimations && !_ticker.isActive) {
      _ticker.start();
    }
    _frame.value = widget.controller.nowMs;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_ensureTicking);
    _ticker.dispose();
    _frame.dispose();
    _blockPainter.dispose();
    super.dispose();
  }

  void _handleTap(TapUpDetails details, Size size) {
    final level = widget.controller.level;
    final layout = BoardLayout.fit(size, level.columns, level.rows);
    final cell = layout.cellAt(details.localPosition);
    if (cell == null) return;
    widget.controller.tapCell(cell.x, cell.y);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _handleTap(details, size),
          child: RepaintBoundary(
            child: ValueListenableBuilder<int>(
              valueListenable: _frame,
              builder: (context, nowMs, _) => CustomPaint(
                size: size,
                painter: GamePainter(
                  controller: widget.controller,
                  nowMs: nowMs,
                  blocks: _blockPainter,
                  effect: _clearEffect,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
