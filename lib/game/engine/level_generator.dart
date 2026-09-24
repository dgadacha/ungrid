import '../models/level.dart';
import '../models/move_result.dart';
import 'board_quality_evaluator.dart';
import 'difficulty_config.dart';
import 'difficulty_evaluator.dart';
import 'level_solver.dart';
import 'move_resolver.dart';
import 'puzzle_analysis.dart';
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
    required this.analysis,
    required this.attempts,
    required this.accepted,
    required this.distance,
  });

  final Level level;
  final SolveResult solveResult;
  final DifficultyEvaluation difficulty;
  final BoardQuality quality;

  /// Ce que le niveau demande au joueur : repositionnements, décisions,
  /// erreurs possibles.
  final PuzzleAnalysis analysis;

  /// Nombre de candidats produits avant celui-ci.
  final int attempts;

  /// `true` si le candidat satisfait tous les critères de sa difficulté.
  /// `false` signale un repli : le meilleur trouvé, jamais un niveau cassé.
  final bool accepted;

  /// Écart aux critères visés, 0 quand tout est satisfait.
  final double distance;

  @override
  String toString() =>
      'GeneratedLevel(${level.id}, '
      '${level.blocks.length} blocs, ${solveResult.minimumMoves} coups, '
      '${analysis.moveComplexity.toStringAsFixed(2)} coups/bloc, '
      'décision ${analysis.decisionScore.round()}, '
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
    this.analyzer = const PuzzleAnalyzer(),
    this.maxAttempts = 18,
    this.minimumQuality = 50,
  });

  final PuzzleGenerator generator;
  final LevelSolver solver;
  final DifficultyEvaluator difficultyEvaluator;
  final BoardQualityEvaluator qualityEvaluator;
  final PuzzleAnalyzer analyzer;

  /// Au-delà, on renvoie le meilleur candidat rencontré plutôt que d'échouer.
  final int maxAttempts;

  final double minimumQuality;

  /// Fabrique le niveau [levelId].
  ///
  /// On ne prend pas le premier candidat jouable : c'est ainsi qu'on se
  /// retrouve avec une campagne de niveaux corrects et sans intérêt. Chaque
  /// candidat est éprouvé contre ce que sa tranche exige — coups par bloc,
  /// blocs à repositionner, décisions offertes — et le meilleur l'emporte.
  GeneratedLevel generate({required int levelId, DifficultyConfig? config}) {
    final settings = config ?? DifficultyCurve.configFor(levelId);
    final band = bandFor(levelId);
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
      // coûteux : inutile de résoudre un board qu'on rejettera sur sa forme.
      final exitable = exitableCount(candidate);
      final exitableRatio = exitable / candidate.blocks.length;
      final quality = qualityEvaluator.evaluate(candidate);
      final cheapDistance =
          (exitableRatio > band.maxExitRatio
              ? (exitableRatio - band.maxExitRatio) * 12
              : 0.0) +
          _qualityDistance(quality);
      if (best != null && cheapDistance >= best.distance) continue;

      // Le rembobinage garantit une solution ; le solveur dit laquelle est la
      // plus courte.
      final solveResult = solver.solve(candidate);
      if (!solveResult.solvable) continue;

      // Le rapport coups / blocs se lit directement sur la solution. S'il est
      // déjà hors cible, inutile de payer l'analyse fine, qui rejoue la
      // partie et éprouve chaque alternative.
      final complexity = solveResult.minimumMoves / candidate.blocks.length;
      final complexityGap = complexity < band.minComplexity
          ? (band.minComplexity - complexity) * 8
          : (complexity > band.maxComplexity
                ? (complexity - band.maxComplexity) * 4
                : 0.0);
      if (best != null && cheapDistance + complexityGap >= best.distance) {
        continue;
      }

      final analysis = analyzer.analyse(candidate, solveResult);
      final difficulty = difficultyEvaluator.evaluate(
        candidate,
        solveResult,
        exitable,
      );

      final distance = cheapDistance + _bandDistance(band, analysis);
      final accepted = distance == 0;

      final evaluated = GeneratedLevel(
        level: candidate.copyWith(
          difficulty: difficulty.tier,
          optimalMoves: solveResult.minimumMoves,
        ),
        solveResult: solveResult,
        difficulty: difficulty,
        quality: quality,
        analysis: analysis,
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
      ),
    );
  }

  /// Écart entre ce que le niveau demande et ce que sa tranche exige.
  ///
  /// Zéro signifie « tout est satisfait ». Les manques sont additionnés, de
  /// sorte qu'un candidat presque bon reste préférable à un candidat plat.
  static double _bandDistance(DifficultyBand band, PuzzleAnalysis analysis) {
    var distance = 0.0;

    if (analysis.moveComplexity < band.minComplexity) {
      distance += (band.minComplexity - analysis.moveComplexity) * 8;
    }
    if (analysis.moveComplexity > band.maxComplexity) {
      distance += (analysis.moveComplexity - band.maxComplexity) * 4;
    }
    if (analysis.multiMoveRatio < band.minMultiMoveRatio) {
      distance += (band.minMultiMoveRatio - analysis.multiMoveRatio) * 4;
    }
    if (analysis.decisionScore < band.minDecisionScore) {
      distance += (band.minDecisionScore - analysis.decisionScore) / 25;
    }
    return distance;
  }

  /// Blocs qui quitteraient la grille dès le premier coup.
  ///
  /// Passe par le résolveur partagé : une tuile sur le trajet suffit à retenir
  /// le bloc, et l'ignorer ici ferait compter comme sortie immédiate un coup
  /// qui n'en est pas une — la mesure qui plafonne les sorties gratuites
  /// deviendrait fausse.
  static int exitableCount(Level level) {
    final cells = level.stopMask();
    for (final block in level.blocks) {
      cells[block.y * level.columns + block.x] |= cellOccupied;
    }

    var count = 0;
    for (final block in level.blocks) {
      final move = MoveResolver.resolve(
        cell: block.y * level.columns + block.x,
        stepX: block.direction.dx,
        stepY: block.direction.dy,
        columns: level.columns,
        rows: level.rows,
        cells: cells,
      );
      if (move.outcome == MoveOutcome.exited) count++;
    }
    return count;
  }

  double _qualityDistance(BoardQuality quality) =>
      quality.score >= minimumQuality
      ? 0
      : (minimumQuality - quality.score) / 10;
}
