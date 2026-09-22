import 'dart:math' as math;

import '../models/direction.dart';
import '../models/level.dart';

/// Note de lisibilité d'un board, indépendante de sa difficulté.
class BoardQuality {
  const BoardQuality({
    required this.score,
    required this.density,
    required this.directionBalance,
    required this.spatialBalance,
    required this.emptyRowsOrColumns,
    required this.dominantDirectionRatio,
    required this.perfectlySymmetric,
  });

  /// Note de 0 à 100.
  final double score;

  final double density;

  /// 1 quand les quatre directions sont équilibrées, 0 quand une seule règne.
  final double directionBalance;

  /// 1 quand les blocs se répartissent bien entre les quadrants.
  final double spatialBalance;

  final int emptyRowsOrColumns;
  final double dominantDirectionRatio;
  final bool perfectlySymmetric;

  @override
  String toString() => 'BoardQuality(${score.round()}/100, '
      'densité ${(density * 100).round()}%, '
      'directions ${(directionBalance * 100).round()}%)';
}

/// Évalue l'aspect d'un board : un puzzle correct mais laid se repère tout de
/// suite comme « généré ».
class BoardQualityEvaluator {
  const BoardQualityEvaluator();

  BoardQuality evaluate(Level level) {
    final blocks = level.blocks;
    final density = level.density;

    // Répartition des directions.
    final counts = <Direction, int>{for (final d in Direction.values) d: 0};
    for (final block in blocks) {
      counts[block.direction] = counts[block.direction]! + 1;
    }
    final maxDirection = counts.values.reduce(math.max);
    final dominantRatio = blocks.isEmpty ? 0.0 : maxDirection / blocks.length;
    final usedDirections = counts.values.where((c) => c > 0).length;
    final directionBalance =
        (1 - (dominantRatio - 0.25) / 0.75).clamp(0.0, 1.0) *
            (usedDirections / 4);

    // Répartition spatiale par quadrant.
    final quadrants = List<int>.filled(4, 0);
    final halfX = level.columns / 2;
    final halfY = level.rows / 2;
    for (final block in blocks) {
      quadrants[(block.x < halfX ? 0 : 1) + (block.y < halfY ? 0 : 2)]++;
    }
    final ideal = blocks.length / 4;
    final deviation = ideal == 0
        ? 0.0
        : quadrants
                .map((c) => (c - ideal).abs())
                .reduce((a, b) => a + b) /
            (2 * blocks.length);
    final spatialBalance = (1 - deviation).clamp(0.0, 1.0);

    // Lignes et colonnes entièrement vides : le board paraît coupé en deux.
    final rowsUsed = List<bool>.filled(level.rows, false);
    final columnsUsed = List<bool>.filled(level.columns, false);
    for (final block in blocks) {
      rowsUsed[block.y] = true;
      columnsUsed[block.x] = true;
    }
    final emptyLines = rowsUsed.where((used) => !used).length +
        columnsUsed.where((used) => !used).length;

    final symmetric = _isPerfectlySymmetric(level);

    var score = 100.0;

    // Densité : trop vide, le board paraît inachevé ; trop plein, plus rien
    // ne glisse.
    const idealDensity = 0.32;
    score -= (density - idealDensity).abs() * 120;

    score -= (1 - directionBalance) * 30;
    score -= (1 - spatialBalance) * 25;
    score -= emptyLines * 6;
    if (symmetric) score -= 12;
    if (dominantRatio > 0.5) score -= 15;

    return BoardQuality(
      score: score.clamp(0.0, 100.0),
      density: density,
      directionBalance: directionBalance,
      spatialBalance: spatialBalance,
      emptyRowsOrColumns: emptyLines,
      dominantDirectionRatio: dominantRatio,
      perfectlySymmetric: symmetric,
    );
  }

  /// Une symétrie parfaite trahit la machine ; une symétrie partielle, elle,
  /// est agréable et n'est pas pénalisée.
  bool _isPerfectlySymmetric(Level level) {
    if (level.blocks.length < 4) return false;
    final grid = <int, Direction>{};
    for (final block in level.blocks) {
      grid[block.y * level.columns + block.x] = block.direction;
    }
    for (final block in level.blocks) {
      final mirrorX = level.columns - 1 - block.x;
      final mirror = grid[block.y * level.columns + mirrorX];
      if (mirror == null) return false;
      if (mirror != block.direction && mirror != block.direction.opposite) {
        return false;
      }
    }
    return true;
  }
}
