import 'dart:math' as math;

import '../models/level.dart';
import 'level_solver.dart';
import 'solve_result.dart';

/// Poids du score de difficulté.
///
/// Ils sont provisoires et le resteront tant que le benchmark n'aura pas dit
/// ce que chaque métrique vaut réellement : figer des seuils avant d'avoir la
/// distribution reviendrait à décider de la difficulté sans l'avoir mesurée.
///
/// Une règle tient déjà, elle : le rapport coups / blocs pèse **moins** que
/// les métriques de décision. Un niveau qui demande trente taps obligatoires
/// n'est pas difficile, il est long.
class ScoringWeights {
  const ScoringWeights({
    this.decisionComplexity = 26,
    this.optimalPathNarrowness = 18,
    this.temptingWrongMoveRatio = 16,
    this.dependencyComplexity = 14,
    this.meaningfulStopInteractions = 8,
    this.multiMoveComplexity = 10,
    this.stateSpaceComplexity = 8,
    this.moveComplexity = 8,
    this.trivialityPenalty = 22,
  });

  final double decisionComplexity;
  final double optimalPathNarrowness;
  final double temptingWrongMoveRatio;
  final double dependencyComplexity;
  final double meaningfulStopInteractions;
  final double multiMoveComplexity;
  final double stateSpaceComplexity;

  /// Volontairement bas : la longueur n'est pas la difficulté.
  final double moveComplexity;

  /// Retranchée, celle-là.
  final double trivialityPenalty;

  static const ScoringWeights standard = ScoringWeights();
}

/// Ce qu'un niveau demande vraiment au joueur.
///
/// Le nombre de coups ne dit presque rien : deux niveaux de dix-huit coups
/// n'ont rien à voir si l'un n'offre qu'une action possible à chaque étape et
/// l'autre trois. Ce qui coûte, c'est de décider — et c'est ce qu'on mesure
/// ici.
class PuzzleAnalysis {
  const PuzzleAnalysis({
    required this.blockCount,
    required this.cellCount,
    required this.optimalMoves,
    required this.multiMoveBlocks,
    required this.maxMovesForSingleBlock,
    required this.decisionStates,
    required this.forcedStates,
    required this.narrowStates,
    required this.averageChoices,
    required this.choicesOffered,
    required this.wrongMoveOpportunities,
    required this.deadEndOpportunities,
    required this.dependencyMoves,
    required this.stopTileCount,
    required this.usedStopTiles,
    required this.stopTileInteractions,
    required this.meaningfulStopInteractions,
    required this.exploredStates,
    this.unresolvedAlternatives = 0,
  });

  final int blockCount;
  final int cellCount;
  final int optimalMoves;

  /// Blocs qu'il faut toucher plus d'une fois : repositionnés avant de sortir.
  final int multiMoveBlocks;

  /// Taps sur le bloc le plus sollicité de la solution.
  final int maxMovesForSingleBlock;

  /// Étapes de la solution où au moins deux coups étaient jouables.
  final int decisionStates;

  /// Étapes où un seul coup l'était : rien à décider.
  final int forcedStates;

  /// Étapes qui offraient un choix, mais dont un seul coup restait optimal.
  final int narrowStates;

  /// Nombre moyen de coups jouables le long de la solution.
  final double averageChoices;

  /// Coups écartés le long de la solution, tous états confondus.
  ///
  /// Un refus ne compte pas : il ne change rien au board, et ne se choisit
  /// donc pas.
  final int choicesOffered;

  /// Coups qui allongent la partie sans la perdre : l'erreur ordinaire, celle
  /// qu'on rattrape avec une annulation.
  final int wrongMoveOpportunities;

  /// Coups qui condamnent la partie. À doser : un piège doit se comprendre
  /// après coup, sinon il est seulement injuste.
  final int deadEndOpportunities;

  /// Coups de la solution qui changent ce que les autres blocs peuvent faire.
  final int dependencyMoves;

  final int stopTileCount;

  /// Tuiles que la solution emprunte réellement.
  final int usedStopTiles;

  /// Arrêts sur tuile le long de la solution optimale.
  final int stopTileInteractions;

  /// Parmi eux, ceux qui modifient les possibilités d'un autre bloc.
  ///
  /// `A → ● → bord` en compte un, signifiant zéro : la tuile allonge la
  /// solution sans rien demander au joueur. C'est la distinction qui décide si
  /// une tuile mérite sa place.
  final int meaningfulStopInteractions;

  final int exploredStates;

  /// Alternatives dont le coût n'a pas tenu dans le budget d'exploration.
  ///
  /// Elles ne comptent ni comme piège ni comme erreur : les confondre avec des
  /// impasses créditerait les grands boards de pièges imaginaires. Le nombre
  /// se publie pour qu'on sache sur quoi l'analyse s'appuie.
  final int unresolvedAlternatives;

  /// Coups par bloc. À 1,00, chaque bloc sort d'un seul tap et le glissement
  /// ne sert à rien.
  double get moveComplexity => blockCount == 0 ? 1 : optimalMoves / blockCount;

  /// Même chose, nommée telle que le benchmark la lit.
  double get averageMovesPerBlock => moveComplexity;

  /// Part des blocs qu'il faut jouer plusieurs fois.
  double get multiMoveRatio =>
      blockCount == 0 ? 0 : multiMoveBlocks / blockCount;

  /// Part des étapes où le joueur avait un choix à faire.
  double get decisionRatio =>
      optimalMoves == 0 ? 0 : decisionStates / optimalMoves;

  /// Tuiles posées mais jamais empruntées : de la décoration.
  int get unusedStopTileCount => stopTileCount - usedStopTiles;

  double get stopTileDensity => cellCount == 0 ? 0 : stopTileCount / cellCount;

  /// Part des arrêts sur tuile qui créent une dépendance.
  ///
  /// Cette mesure compte bien plus que le nombre de tuiles : dix tuiles qui
  /// n'obligent qu'à taper deux fois ne valent pas une seule qui replace un
  /// bloc en travers de la route d'un autre.
  double get stopDependencyScore => stopTileInteractions == 0
      ? 0
      : meaningfulStopInteractions / stopTileInteractions;

  /// Part des coups de la solution qui engagent un autre bloc.
  double get dependencyComplexity =>
      optimalMoves == 0 ? 0 : dependencyMoves / optimalMoves;

  /// Étroitesse du chemin optimal, de 0 à 1.
  ///
  /// Puisque la réserve vaut exactement la solution optimale, un seul coup
  /// sous-optimal fait perdre. On mesure donc les étapes où, parmi plusieurs
  /// coups jouables, un seul laissait la partie gagnable au plus court : à 0,
  /// tous les chemins se valent ; à 1, il n'y en a jamais qu'un.
  double get optimalPathNarrowness =>
      decisionStates == 0 ? 0 : narrowStates / decisionStates;

  /// Coups écartés qui changent l'état et coûtent la partie ou des coups.
  ///
  /// Les refus en sont exclus : ils ne déplacent rien, et ne tentent
  /// personne.
  int get temptingWrongMoves => wrongMoveOpportunities + deadEndOpportunities;

  /// Alternatives qui modifient réellement le board.
  int get meaningfulAlternativeCount => choicesOffered;

  double get temptingWrongMoveRatio => meaningfulAlternativeCount == 0
      ? 0
      : temptingWrongMoves / meaningfulAlternativeCount;

  /// Taille de l'arbre exploré, ramenée entre 0 et 1.
  ///
  /// Échelle logarithmique, bornée au budget maximal qu'un solveur accepte de
  /// dépenser sur un candidat : au-delà, on ne saurait de toute façon plus
  /// distinguer deux niveaux, l'exploration ayant été coupée. Un board deux
  /// fois plus grand explose le compte sans être deux fois plus dur, d'où le
  /// logarithme.
  double get stateSpaceComplexity =>
      (math.log(exploredStates + 1) / math.log(120000)).clamp(0.0, 1.0);

  /// Ce que le niveau contient de taps obligatoires.
  ///
  /// Une étape sans choix ne demande rien, et un arrêt sur tuile qui
  /// n'engage personne non plus : les deux gonflent le nombre de coups sans
  /// rien apporter. C'est exactement ce qu'il faut retrancher du score, sans
  /// quoi il suffirait d'aligner des tuiles pour paraître difficile.
  double get trivialityPenalty {
    if (optimalMoves == 0) return 1;
    final idleStops = stopTileInteractions - meaningfulStopInteractions;
    return ((forcedStates + idleStops) / optimalMoves).clamp(0.0, 1.0);
  }

  /// Note de décision, de 0 à 100.
  ///
  /// Elle pèse ce qui fait hésiter : avoir plusieurs coups plausibles, pouvoir
  /// se tromper, devoir repositionner. La taille du board n'y entre pas, et la
  /// présence d'une tuile non plus : une tuile ne relève ce score que si elle
  /// crée des choix, pas parce qu'elle existe.
  double get decisionScore {
    final choices = ((averageChoices - 1) / 3.0).clamp(0.0, 1.0) * 30;
    final decisions = decisionRatio.clamp(0.0, 1.0) * 20;
    final wrong = (wrongMoveOpportunities / 12).clamp(0.0, 1.0) * 25;
    final dead = (deadEndOpportunities / 6).clamp(0.0, 1.0) * 15;
    final multi = (multiMoveRatio / 0.3).clamp(0.0, 1.0) * 10;
    return choices + decisions + wrong + dead + multi;
  }

  /// Note globale, de 0 à 100.
  double difficultyScore([ScoringWeights w = ScoringWeights.standard]) {
    final total =
        w.decisionComplexity +
        w.optimalPathNarrowness +
        w.temptingWrongMoveRatio +
        w.dependencyComplexity +
        w.meaningfulStopInteractions +
        w.multiMoveComplexity +
        w.stateSpaceComplexity +
        w.moveComplexity;

    final raw =
        w.decisionComplexity * (decisionScore / 100) +
        w.optimalPathNarrowness * optimalPathNarrowness +
        w.temptingWrongMoveRatio * temptingWrongMoveRatio +
        w.dependencyComplexity * dependencyComplexity +
        w.meaningfulStopInteractions *
            (meaningfulStopInteractions / 4).clamp(0.0, 1.0) +
        w.multiMoveComplexity * (multiMoveRatio / 0.4).clamp(0.0, 1.0) +
        w.stateSpaceComplexity * stateSpaceComplexity +
        w.moveComplexity * ((moveComplexity - 1) / 1.0).clamp(0.0, 1.0);

    final score = raw / total * 100 - w.trivialityPenalty * trivialityPenalty;
    return score.clamp(0.0, 100.0);
  }

  Map<String, dynamic> toJson() => {
    'blockCount': blockCount,
    'optimalMoves': optimalMoves,
    'moveComplexity': moveComplexity,
    'multiMoveBlocks': multiMoveBlocks,
    'multiMoveRatio': multiMoveRatio,
    'maxMovesForSingleBlock': maxMovesForSingleBlock,
    'averageChoices': averageChoices,
    'decisionRatio': decisionRatio,
    'decisionScore': decisionScore,
    'optimalPathNarrowness': optimalPathNarrowness,
    'temptingWrongMoves': temptingWrongMoves,
    'temptingWrongMoveRatio': temptingWrongMoveRatio,
    'wrongMoveOpportunities': wrongMoveOpportunities,
    'deadEndOpportunities': deadEndOpportunities,
    'dependencyComplexity': dependencyComplexity,
    'stopTileCount': stopTileCount,
    'stopTileDensity': stopTileDensity,
    'stopTileInteractions': stopTileInteractions,
    'meaningfulStopInteractions': meaningfulStopInteractions,
    'unusedStopTileCount': unusedStopTileCount,
    'stopDependencyScore': stopDependencyScore,
    'stateSpaceComplexity': stateSpaceComplexity,
    'trivialityPenalty': trivialityPenalty,
    'exploredStates': exploredStates,
    'unresolvedAlternatives': unresolvedAlternatives,
    'difficultyScore': difficultyScore(),
  };

  @override
  String toString() =>
      'PuzzleAnalysis(${moveComplexity.toStringAsFixed(2)} '
      'coups/bloc, $multiMoveBlocks rejoués, $stopTileCount tuiles dont '
      '$meaningfulStopInteractions utiles, '
      'décision ${decisionScore.round()}, '
      'difficulté ${difficultyScore().round()})';
}

/// Analyse fine d'un niveau, coûteuse : elle rejoue la solution et éprouve les
/// alternatives à chaque étape.
///
/// Réservée aux candidats déjà retenus sur des critères bon marché, sans quoi
/// la génération d'un millier de niveaux ne finirait pas.
class PuzzleAnalyzer {
  const PuzzleAnalyzer({
    this.solver = const LevelSolver(maxExploredStates: 4000),
  });

  final LevelSolver solver;

  PuzzleAnalysis analyse(Level level, SolveResult solution) {
    final blockCount = level.blocks.length;
    if (!solution.solvable || blockCount == 0) {
      return PuzzleAnalysis(
        blockCount: blockCount,
        cellCount: level.cellCount,
        optimalMoves: solution.minimumMoves,
        multiMoveBlocks: 0,
        maxMovesForSingleBlock: 0,
        decisionStates: 0,
        forcedStates: 0,
        narrowStates: 0,
        averageChoices: 0,
        choicesOffered: 0,
        wrongMoveOpportunities: 0,
        deadEndOpportunities: 0,
        dependencyMoves: 0,
        stopTileCount: level.allStopTiles.length,
        usedStopTiles: 0,
        stopTileInteractions: 0,
        meaningfulStopInteractions: 0,
        exploredStates: solution.exploredStates,
      );
    }

    final played = <String, int>{};
    for (final id in solution.exampleSolution) {
      played[id] = (played[id] ?? 0) + 1;
    }
    final multiMove = played.values.where((count) => count > 1).length;
    final maxForOne = played.values.fold<int>(0, (a, b) => a > b ? a : b);

    final walk = solver.walkSolution(level, solution.exampleSolution);

    var decisionStates = 0;
    var forcedStates = 0;
    var narrowStates = 0;
    for (var i = 0; i < walk.choices.length; i++) {
      if (walk.choices[i] >= 2) {
        decisionStates++;
        if (walk.optimalChoices[i] <= 1) narrowStates++;
      } else {
        forcedStates++;
      }
    }

    return PuzzleAnalysis(
      blockCount: blockCount,
      cellCount: level.cellCount,
      optimalMoves: solution.minimumMoves,
      multiMoveBlocks: multiMove,
      maxMovesForSingleBlock: maxForOne,
      decisionStates: decisionStates,
      forcedStates: forcedStates,
      narrowStates: narrowStates,
      averageChoices: walk.choices.isEmpty
          ? 0
          : walk.choices.fold<int>(0, (a, b) => a + b) / walk.choices.length,
      // Un coup par étape est celui qu'on joue : les autres sont les choix
      // réellement offerts, et c'est parmi eux qu'on peut se tromper.
      choicesOffered: walk.choices.fold<int>(
        0,
        (a, b) => a + (b > 0 ? b - 1 : 0),
      ),
      wrongMoveOpportunities: walk.wrongMoves,
      deadEndOpportunities: walk.deadEnds,
      dependencyMoves: walk.dependencyMoves,
      unresolvedAlternatives: walk.unresolvedAlternatives,
      stopTileCount: level.allStopTiles.length,
      usedStopTiles: walk.usedStopTiles,
      stopTileInteractions: walk.stopInteractions,
      meaningfulStopInteractions: walk.meaningfulStopInteractions,
      exploredStates: solution.exploredStates,
    );
  }
}
