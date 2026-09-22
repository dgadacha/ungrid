import '../models/level.dart';
import 'board_quality_evaluator.dart';
import 'difficulty_config.dart';
import 'difficulty_evaluator.dart';
import 'level_solver.dart';
import 'seeded_random.dart';
import 'slide_generator.dart';
import 'solve_result.dart';

/// Un niveau généré, accompagné de tout ce qui a servi à le juger.
class GeneratedLevel {
  const GeneratedLevel({
    required this.level,
    required this.solveResult,
    required this.difficulty,
    required this.quality,
    required this.attempts,
    required this.accepted,
    required this.distance,
  });

  final Level level;
  final SolveResult solveResult;
  final DifficultyEvaluation difficulty;
  final BoardQuality quality;

  /// Nombre de candidats produits avant celui-ci.
  final int attempts;

  /// `true` si le candidat satisfait tous les critères de sa difficulté.
  /// `false` signale un repli : le meilleur trouvé, jamais un niveau cassé.
  final bool accepted;

  /// Écart aux critères visés, 0 quand tout est satisfait.
  final double distance;

  @override
  String toString() => 'GeneratedLevel(${level.id}, '
      '${level.blocks.length} blocs, ${solveResult.minimumMoves} coups, '
      'score ${difficulty.score.round()}, visuel ${quality.score.round()}, '
      '${accepted ? "accepté" : "replié"} en $attempts essai(s))';
}

/// Chaîne complète de fabrication d'un niveau.
///
/// Rembobinage, puis solveur, puis analyse de la difficulté et de l'aspect. Un
/// candidat qui échoue est jeté et un autre est produit avec la seed suivante.
/// Aucun board non validé ne sort d'ici.
class LevelGenerator {
  const LevelGenerator({
    this.generator = const SlideGenerator(),
    this.solver = const LevelSolver(),
    this.difficultyEvaluator = const DifficultyEvaluator(),
    this.qualityEvaluator = const BoardQualityEvaluator(),
    this.maxAttempts = 14,
    this.minimumQuality = 50,
  });

  final PuzzleGenerator generator;
  final LevelSolver solver;
  final DifficultyEvaluator difficultyEvaluator;
  final BoardQualityEvaluator qualityEvaluator;

  /// Au-delà, on renvoie le meilleur candidat rencontré plutôt que d'échouer.
  final int maxAttempts;

  final double minimumQuality;

  GeneratedLevel generate({required int levelId, DifficultyConfig? config}) {
    final settings = config ?? DifficultyCurve.configFor(levelId);
    GeneratedLevel? best;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final seed = seedForLevel(levelId, attempt);
      final candidate = generator.buildCandidate(
        levelId: levelId,
        seed: seed,
        config: settings,
      );
      if (candidate == null || !candidate.isStructurallyValid) continue;

      // Deux examens bon marché avant l'exploration, qui est de loin le plus
      // coûteux : inutile de résoudre un board qu'on rejettera de toute façon
      // sur sa forme.
      final exitable = exitableCount(candidate);
      final exitableRatio = exitable / candidate.blocks.length;
      final quality = qualityEvaluator.evaluate(candidate);
      final cheapDistance = (exitableRatio > settings.maxExitableRatio
              ? (exitableRatio - settings.maxExitableRatio) * 12
              : 0.0) +
          _qualityDistance(quality);
      if (best != null && cheapDistance >= best.distance) continue;

      // Le rembobinage garantit une solution ; le solveur dit laquelle est la
      // plus courte, et ce que le niveau cache d'impasses.
      final solveResult = solver.solve(candidate);
      if (!solveResult.solvable) continue;

      final difficulty =
          difficultyEvaluator.evaluate(candidate, solveResult, exitable);

      final distance = difficultyEvaluator.distanceTo(settings, difficulty) +
          _qualityDistance(quality);
      final accepted = distance == 0;

      final evaluated = GeneratedLevel(
        level: candidate.copyWith(
          difficulty: difficulty.tier,
          optimalMoves: solveResult.minimumMoves,
        ),
        solveResult: solveResult,
        difficulty: difficulty,
        quality: quality,
        attempts: attempt + 1,
        accepted: accepted,
        distance: distance,
      );

      if (accepted) return evaluated;
      if (best == null || distance < best.distance) best = evaluated;
    }

    if (best != null) return best;

    // Aucun candidat : on relâche la difficulté et on reprend. La solvabilité,
    // elle, n'est jamais négociée.
    return generate(
      levelId: levelId,
      config: DifficultyConfig.fromScalar(
        (settings.scalar - 0.15).clamp(0.0, 1.0),
        maxWalls: settings.maxWalls,
      ),
    );
  }

  /// Blocs qui quitteraient la grille dès le premier coup.
  static int exitableCount(Level level) {
    final occupied = <int>{
      for (final block in level.blocks) block.y * level.columns + block.x,
    };
    final walls = <int>{
      for (final wall in level.walls) wall.y * level.columns + wall.x,
    };

    var count = 0;
    for (final block in level.blocks) {
      var x = block.x + block.direction.dx;
      var y = block.y + block.direction.dy;
      var clear = true;
      while (x >= 0 && y >= 0 && x < level.columns && y < level.rows) {
        final cell = y * level.columns + x;
        if (occupied.contains(cell) || walls.contains(cell)) {
          clear = false;
          break;
        }
        x += block.direction.dx;
        y += block.direction.dy;
      }
      if (clear) count++;
    }
    return count;
  }

  double _qualityDistance(BoardQuality quality) =>
      quality.score >= minimumQuality
          ? 0
          : (minimumQuality - quality.score) / 10;
}
