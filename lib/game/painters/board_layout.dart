import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../app/constants.dart';
import '../models/grid_position.dart';

/// Géométrie de la grille à l'écran.
///
/// Partagée par le dessin et la détection du toucher : une seule source pour
/// la position des cases, donc aucun risque de viser à côté de ce qu'on voit.
class BoardLayout {
  const BoardLayout({
    required this.rect,
    required this.cellSize,
    required this.columns,
    required this.rows,
  });

  /// Le board, carré, centré dans l'espace disponible.
  final Rect rect;
  final double cellSize;
  final int columns;
  final int rows;

  factory BoardLayout.fit(Size available, int columns, int rows) {
    final side =
        math.min(available.width, available.height) -
        GameMetrics.boardPadding * 2;
    final board = math.max(side, 0.0);
    final cell = board / math.max(columns, rows);
    final origin = Offset(
      (available.width - board) / 2,
      (available.height - board) / 2,
    );
    return BoardLayout(
      rect: origin & Size(board, board),
      cellSize: cell,
      columns: columns,
      rows: rows,
    );
  }

  Rect cellRect(int x, int y) => Rect.fromLTWH(
    rect.left + x * cellSize,
    rect.top + y * cellSize,
    cellSize,
    cellSize,
  );

  /// Case visée par un toucher, `null` en dehors de la grille.
  GridPosition? cellAt(Offset position) {
    if (!rect.contains(position)) return null;
    final x = ((position.dx - rect.left) / cellSize).floor();
    final y = ((position.dy - rect.top) / cellSize).floor();
    if (x < 0 || y < 0 || x >= columns || y >= rows) return null;
    return GridPosition(x, y);
  }
}
