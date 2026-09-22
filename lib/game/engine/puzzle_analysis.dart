import '../models/level.dart';
import 'level_solver.dart';
import 'solve_result.dart';

/// Ce qu'un niveau demande vraiment au joueur.
///
/// Le nombre de coups ne dit presque rien : deux niveaux de dix-huit coups
/// n'ont rien à voir si l'un n'offre qu'une action possible à chaque étape et
/// l'autre trois. Ce qui coûte, c'est de décider — et c'est ce qu'on mesure
/// ici.
class PuzzleAnalysis {
  const PuzzleAnalysis({
    required this.blockCount,
    required this.optimalMoves,
    required this.multiMoveBlocks,
    required this.decisionStates,
    required this.averageChoices,
    required this.wrongMoveOpportunities,
    required this.deadEndOpportunities,
    required this.wallInfluence,
    required this.exploredStates,
  });

  final int blockCount;
  final int optimalMoves;

  /// Blocs qu'il faut toucher plus d'une fois : repositionnés avant de sortir.
  final int multiMoveBlocks;

  /// Étapes de la solution où au moins deux coups étaient jouables.
  final int decisionStates;

  /// Nombre moyen de coups jouables le long de la solution.
  final double averageChoices;

  /// Coups qui allongent la partie sans la perdre : l'erreur ordinaire, celle
  /// qu'on rattrape avec une annulation.
  final int wrongMoveOpportunities;

  /// Coups qui condamnent la partie. À doser : un piège doit se comprendre
  /// après coup, sinon il est seulement injuste.
  final int deadEndOpportunities;

  /// Murs qui arrêtent un bloc au cours de la solution.
  ///
  /// Vaut nécessairement zéro : un bloc arrêté par un mur ne repartira jamais,
  /// puisque sa direction est fixe et que le mur ne bouge pas. Le rôle des
  /// murs est donc purement spatial — ils resserrent la grille. On garde la
  /// mesure comme garde-fou : une valeur non nulle signalerait une solution
  /// qui condamne un bloc, donc un niveau cassé.
  final int wallInfluence;

  final int exploredStates;

  /// Coups par bloc. À 1,00, chaque bloc sort d'un seul tap et le glissement
  /// ne sert à rien.
  double get moveComplexity =>
      blockCount == 0 ? 1 : optimalMoves / blockCount;

  /// Part des blocs qu'il faut jouer plusieurs fois.
  double get multiMoveRatio =>
      blockCount == 0 ? 0 : multiMoveBlocks / blockCount;

  /// Part des étapes où le joueur avait un choix à faire.
  double get decisionRatio =>
      optimalMoves == 0 ? 0 : decisionStates / optimalMoves;

  /// Note de décision, de 0 à 100.
  ///
  /// Elle pèse ce qui fait hésiter : devoir repositionner un bloc avant de le
  /// sortir, avoir plusieurs coups plausibles, et surtout pouvoir se tromper —
  /// un coup qui rallonge la partie, voire qui la condamne. La taille du board
  /// n'y entre pas : un grand board dont tout sort d'un tap reste facile.
  double get decisionScore {
    final reposition = ((moveComplexity - 1) / 0.25).clamp(0.0, 1.0) * 25;
    final multi = (multiMoveRatio / 0.3).clamp(0.0, 1.0) * 15;
    final choices = ((averageChoices - 1) / 3.0).clamp(0.0, 1.0) * 20;
    final decisions = decisionRatio.clamp(0.0, 1.0) * 10;
    final wrong = (wrongMoveOpportunities / 12).clamp(0.0, 1.0) * 20;
    final traps = (deadEndOpportunities / 5).clamp(0.0, 1.0) * 10;
    return reposition + multi + choices + decisions + wrong + traps;
  }

  @override
  String toString() => 'PuzzleAnalysis(${moveComplexity.toStringAsFixed(2)} '
      'coups/bloc, $multiMoveBlocks rejoués, '
      'décision ${decisionScore.round()})';
}

/// Analyse fine d'un niveau, coûteuse : elle rejoue la solution et éprouve les
/// alternatives à chaque étape.
///
/// Réservée aux candidats déjà retenus sur des critères bon marché, sans quoi
/// la génération d'un millier de niveaux ne finirait pas.
class PuzzleAnalyzer {
  const PuzzleAnalyzer({this.solver = const LevelSolver(maxExploredStates: 4000)});

  final LevelSolver solver;

  PuzzleAnalysis analyse(Level level, SolveResult solution) {
    final blockCount = level.blocks.length;
    if (!solution.solvable || blockCount == 0) {
      return PuzzleAnalysis(
        blockCount: blockCount,
        optimalMoves: solution.minimumMoves,
        multiMoveBlocks: 0,
        decisionStates: 0,
        averageChoices: 0,
        wrongMoveOpportunities: 0,
        deadEndOpportunities: 0,
        wallInfluence: 0,
        exploredStates: solution.exploredStates,
      );
    }

    final played = <String, int>{};
    for (final id in solution.exampleSolution) {
      played[id] = (played[id] ?? 0) + 1;
    }
    final multiMove = played.values.where((count) => count > 1).length;

    final walk = solver.walkSolution(level, solution.exampleSolution);

    return PuzzleAnalysis(
      blockCount: blockCount,
      optimalMoves: solution.minimumMoves,
      multiMoveBlocks: multiMove,
      decisionStates: walk.choices.where((count) => count >= 2).length,
      averageChoices: walk.choices.isEmpty
          ? 0
          : walk.choices.fold<int>(0, (a, b) => a + b) / walk.choices.length,
      wrongMoveOpportunities: walk.wrongMoves,
      deadEndOpportunities: walk.deadEnds,
      wallInfluence: walk.wallsUsed,
      exploredStates: solution.exploredStates,
    );
  }
}
