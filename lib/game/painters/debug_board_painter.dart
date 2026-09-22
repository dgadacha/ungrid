import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../models/level.dart';
import 'block_painter.dart';
import 'board_layout.dart';

/// Rendu du board pour l'écran d'analyse.
///
/// Superpose au niveau ce qu'on ne voit pas en jouant : le graphe de
/// dépendances, la couche de chaque bloc, et l'état d'une résolution en cours.
class DebugBoardPainter extends CustomPainter {
  DebugBoardPainter({
    required this.level,
    required this.blocks,
    required this.positions,
    required this.removed,
    this.nextInSolution,
  });

  final Level level;
  final BlockPainter blocks;

  /// Case occupée par chaque bloc au point où en est la résolution : les blocs
  /// se déplacent, leur position de départ ne suffit plus à les dessiner.
  final List<int> positions;

  /// Blocs déjà sortis dans la résolution pas à pas.
  final Set<int> removed;

  /// Bloc que la solution propose de jouer maintenant.
  final int? nextInSolution;

  final Paint _highlightPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = UngridColors.danger;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = BoardLayout.fit(size, level.columns, level.rows);
    if (layout.cellSize <= 0) return;

    for (var y = 0; y < level.rows; y++) {
      for (var x = 0; x < level.columns; x++) {
        blocks.paintEmptyCell(canvas, layout.cellRect(x, y));
      }
    }

    for (final wall in level.walls) {
      blocks.paintWall(canvas, layout.cellRect(wall.x, wall.y));
    }

    for (var i = 0; i < level.blocks.length; i++) {
      if (removed.contains(i)) continue;
      final block = level.blocks[i];
      final cell = positions.length > i && positions[i] >= 0
          ? positions[i]
          : block.y * level.columns + block.x;
      final rect = layout.cellRect(cell % level.columns, cell ~/ level.columns);

      blocks.paintBlock(
        canvas,
        rect,
        block.direction,
        UngridColors.blockFor(block.id),
      );
    }

    final next = nextInSolution;
    if (next != null && !removed.contains(next)) {
      final cell = positions.length > next && positions[next] >= 0
          ? positions[next]
          : level.blocks[next].y * level.columns + level.blocks[next].x;
      final rect = layout
          .cellRect(cell % level.columns, cell ~/ level.columns)
          .deflate(2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.22)),
        _highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(DebugBoardPainter oldDelegate) =>
      oldDelegate.level != level ||
      oldDelegate.removed.length != removed.length ||
      oldDelegate.nextInSolution != nextInSolution ||
      !identical(oldDelegate.positions, positions);
}
