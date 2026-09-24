import '../models/difficulty.dart';
import '../models/level.dart';
import 'difficulty_config.dart';
import 'solve_result.dart';

/// Note de difficulté d'un niveau, avec le détail de ce qui l'a produite.
class DifficultyEvaluation {
  const DifficultyEvaluation({
    required this.score,
    required this.tier,
    required this.blockCount,
    required this.minimumMoves,
    required this.repositionRatio,
    required this.exitableRatio,
    required this.deadEndCount,
    required this.decisionPoints,
    required this.forcedMoves,
    required this.trivialPenalty,
    required this.repetitivePenalty,
  });

  final double score;
  final Difficulty tier;

  final int blockCount;
  final int minimumMoves;

  /// Coups de repositionnement par bloc : `0` quand chaque bloc sort d'un seul
  /// coup, davantage quand il faut d'abord dégager le passage.
  final double repositionRatio;

  /// Part des blocs qui peuvent sortir dès le premier coup.
  final double exitableRatio;

  /// Impasses rencontrées par le solveur : la mesure du piège.
  final int deadEndCount;

  final int decisionPoints;
  final int forcedMoves;

  final double trivialPenalty;
  final double repetitivePenalty;

  bool get isTrivial => trivialPenalty > 0;

  @override
  String toString() =>
      'DifficultyEvaluation(${score.toStringAsFixed(1)} ${tier.label}, '
      '$blockCount blocs, $minimumMoves coups)';
}

/// Traduit la forme d'un niveau en une note de difficulté.
///
/// L'échelle
/// ---------
/// Ce qui coûte au joueur, avant tout, c'est de relire le board à chaque coup.
/// Le score part donc du nombre de blocs, qu'un facteur de structure amplifie :
/// un board où il faut repousser des blocs avant d'en sortir un, où peu de
/// sorties sont ouvertes et où de vraies impasses existent, demande beaucoup
/// plus qu'un board de même taille qui se vide dans le désordre.
///
/// Les poids sont un point de départ, réglés sur les statistiques de mille
/// niveaux générés : c'est ici qu'on retouche si la courbe paraît trop douce
/// ou trop raide.
class DifficultyEvaluator {
  const DifficultyEvaluator();

  /// Facteur minimal : un board dont tout sort d'un coup.
  static const double _baseFactor = 1.3;

  /// Part du facteur due aux repositionnements à prévoir.
  static const double _repositionWeight = 1.0;

  /// Part due à la rareté des sorties ouvertes.
  static const double _searchWeight = 0.7;

  /// Part due aux impasses possibles.
  static const double _trapWeight = 0.5;

  static const double _repositionTarget = 1.0;
  static const double _deadEndTarget = 40;

  DifficultyEvaluation evaluate(
    Level level,
    SolveResult solveResult,
    int exitableCount,
  ) {
    final blockCount = level.blocks.length;
    final moves = solveResult.minimumMoves;

    // Repositionnements : chaque bloc sort une fois, le reste est du travail
    // préparatoire.
    final reposition = blockCount == 0
        ? 0.0
        : (moves - blockCount) / blockCount;
    final repositionTerm = (reposition / _repositionTarget)
        .clamp(0.0, 1.0)
        .toDouble();

    final exitableRatio = blockCount == 0 ? 0.0 : exitableCount / blockCount;
    final searchTerm = (1 - exitableRatio).clamp(0.0, 1.0).toDouble();

    final trapTerm = (solveResult.deadEndCount / _deadEndTarget)
        .clamp(0.0, 1.0)
        .toDouble();

    final structureFactor =
        _baseFactor +
        repositionTerm * _repositionWeight +
        searchTerm * _searchWeight +
        trapTerm * _trapWeight;

    var score = blockCount * structureFactor;

    // Un board dont presque tout sort d'emblée n'est pas un puzzle.
    //
    // L'absence de repositionnement, elle, n'est pas une faute : elle reste
    // rare, parce qu'elle suppose un blocage circulaire. On la valorise dans
    // le score, sans en faire un motif de rejet.
    var trivialPenalty = 0.0;
    if (exitableRatio > 0.75) trivialPenalty += 18;

    final repetitivePenalty = _repetitionPenalty(level);

    score -= trivialPenalty;
    score -= repetitivePenalty;
    if (score < 0) score = 0;

    return DifficultyEvaluation(
      score: score,
      tier: tierForScore(score),
      blockCount: blockCount,
      minimumMoves: moves,
      repositionRatio: reposition,
      exitableRatio: exitableRatio,
      deadEndCount: solveResult.deadEndCount,
      decisionPoints: solveResult.decisionPointCount,
      forcedMoves: solveResult.forcedMoveCount,
      trivialPenalty: trivialPenalty,
      repetitivePenalty: repetitivePenalty,
    );
  }

  static Difficulty tierForScore(double score) {
    if (score < 18) return Difficulty.easy;
    if (score < 28) return Difficulty.medium;
    if (score < 37) return Difficulty.hard;
    return Difficulty.expert;
  }

  /// Compte les suites de trois blocs identiques alignés et contigus.
  double _repetitionPenalty(Level level) {
    final grid = List<int>.filled(level.rows * level.columns, -1);
    for (var i = 0; i < level.blocks.length; i++) {
      final block = level.blocks[i];
      grid[block.y * level.columns + block.x] = i;
    }

    var runs = 0;
    for (final horizontal in [true, false]) {
      final outer = horizontal ? level.rows : level.columns;
      final inner = horizontal ? level.columns : level.rows;
      for (var a = 0; a < outer; a++) {
        var streak = 0;
        int? current;
        for (var b = 0; b < inner; b++) {
          final index = horizontal
              ? grid[a * level.columns + b]
              : grid[b * level.columns + a];
          final direction = index >= 0
              ? level.blocks[index].direction.index
              : null;
          if (direction != null && direction == current) {
            streak++;
            if (streak == 3) runs++;
          } else {
            streak = direction == null ? 0 : 1;
          }
          current = direction;
        }
      }
    }
    return runs * 4.0;
  }

  /// Écart entre un niveau et ce que la configuration demandait.
  ///
  /// Zéro signifie « tous les critères satisfaits ». Sinon, la valeur sert à
  /// classer les candidats pour ne garder que le moins mauvais.
  double distanceTo(DifficultyConfig config, DifficultyEvaluation evaluation) {
    var distance = 0.0;
    if (evaluation.score < config.minScore) {
      distance += (config.minScore - evaluation.score) / 12;
    }
    if (evaluation.score > config.maxScore) {
      distance += (evaluation.score - config.maxScore) / 12;
    }
    if (evaluation.exitableRatio > config.maxExitableRatio) {
      distance += (evaluation.exitableRatio - config.maxExitableRatio) * 12;
    }
    // Préférences, et non exigences : un niveau où il faut d'abord pousser un
    // bloc vaut mieux qu'un niveau qui se vide dans le désordre. En comptant
    // ces écarts comme une distance, le pipeline continue de chercher un
    // meilleur candidat sans jamais se retrouver sans rien à proposer.
    if (evaluation.repositionRatio <= 0) distance += 0.6;
    if (evaluation.exitableRatio > 0) distance += 0.4;

    distance += evaluation.trivialPenalty / 5;
    if (evaluation.repetitivePenalty > 4) {
      distance += (evaluation.repetitivePenalty - 4) / 8;
    }
    return distance;
  }

  /// Détail des critères non satisfaits, pour le réglage du générateur.
  List<String> unmetCriteria(
    DifficultyConfig config,
    DifficultyEvaluation evaluation,
  ) => [
    if (evaluation.score < config.minScore) 'score bas',
    if (evaluation.score > config.maxScore) 'score haut',
    if (evaluation.exitableRatio > config.maxExitableRatio)
      'trop de sorties immédiates',
    if (evaluation.repositionRatio <= 0) 'aucun repositionnement',
    if (evaluation.exitableRatio > 0) 'sorties offertes',
    if (evaluation.trivialPenalty > 0) 'trivial',
    if (evaluation.repetitivePenalty > 4) 'répétitif',
  ];
}
