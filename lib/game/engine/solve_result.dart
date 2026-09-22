/// Résultat de l'analyse d'un niveau par le solveur.
class SolveResult {
  const SolveResult({
    required this.solvable,
    required this.minimumMoves,
    required this.exploredStates,
    required this.exhaustive,
    required this.maxBranchingFactor,
    required this.averageBranchingFactor,
    required this.forcedMoveCount,
    required this.decisionPointCount,
    required this.deadEndCount,
    required this.exampleSolution,
  });

  const SolveResult.unsolvable({
    required this.exploredStates,
    required this.exhaustive,
    required this.deadEndCount,
  })  : solvable = false,
        minimumMoves = 0,
        maxBranchingFactor = 0,
        averageBranchingFactor = 0,
        forcedMoveCount = 0,
        decisionPointCount = 0,
        exampleSolution = const [];

  final bool solvable;

  /// Nombre minimal de coups pour vider la grille.
  ///
  /// Ce n'est plus le nombre de blocs : un bloc peut devoir être repositionné
  /// plusieurs fois avant de pouvoir sortir.
  final int minimumMoves;

  /// États visités par le parcours en largeur, plafonné par le budget.
  final int exploredStates;

  /// `true` si l'espace d'états a pu être exploré entièrement.
  final bool exhaustive;

  final int maxBranchingFactor;
  final double averageBranchingFactor;

  /// Étapes de la solution où un seul coup était possible.
  final int forcedMoveCount;

  /// Étapes où le joueur avait au moins deux coups.
  final int decisionPointCount;

  /// Configurations rencontrées où plus rien ne bougeait alors qu'il restait
  /// des blocs. C'est la mesure du piège : un niveau qui en compte beaucoup
  /// punit les coups joués sans réfléchir.
  final int deadEndCount;

  /// Une solution possible, sous forme d'identifiants de blocs à toucher.
  final List<String> exampleSolution;

  @override
  String toString() => solvable
      ? 'SolveResult(ok, $minimumMoves coups, $exploredStates états, '
          '$deadEndCount impasses)'
      : 'SolveResult(insoluble, $exploredStates états explorés)';
}
