import 'dart:math' as math;

import '../models/difficulty.dart';

/// Paramètres de génération pour un niveau donné.
///
/// La difficulté est un scalaire continu : les paliers [Difficulty] n'en sont
/// qu'une lecture. Tous les seuils sont interpolés depuis ce scalaire, ce qui
/// évite les marches d'escalier entre deux niveaux consécutifs.
class DifficultyConfig {
  const DifficultyConfig({
    required this.scalar,
    required this.gridSize,
    required this.minBlocks,
    required this.maxBlocks,
    required this.repositionRatio,
    required this.maxExitableRatio,
    required this.minScore,
    required this.maxScore,
    required this.knotCount,
    this.stopTileBudget = 0,
  });

  /// Difficulté visée, entre 0 et 1.
  final double scalar;

  final int gridSize;
  final int minBlocks;
  final int maxBlocks;

  /// Coups de repositionnement par bloc, en plus de sa sortie.
  ///
  /// C'est le levier principal du jeu : à zéro, chaque bloc sort d'un coup et
  /// le niveau se résume à trouver l'ordre ; au-dessus, il faut d'abord
  /// pousser des blocs pour ouvrir des passages.
  final double repositionRatio;

  /// Part maximale de blocs qui peuvent sortir dès le premier coup. Au-delà,
  /// le board se vide sans qu'on ait rien à chercher.
  final double maxExitableRatio;

  final double minScore;
  final double maxScore;

  /// Rondes de blocs à poser avant la construction.
  ///
  /// Une ronde force un bloc à être joué deux fois, mais elle coûte quatre
  /// blocs pour ce seul coup — et surtout, elle fige quatre cases avant même
  /// que le rembobinage commence. Un board qui n'est fait que de rondes se
  /// ressemble d'un niveau à l'autre : c'est le motif qu'on voit, plus le
  /// puzzle.
  ///
  /// Depuis les tuiles d'arrêt, elles ne sont plus le seul moyen de faire
  /// monter le rapport coups / blocs. On en pose donc peu, et on laisse la
  /// place au rembobinage.
  final int knotCount;

  /// Tuiles d'arrêt que la construction s'autorise à poser.
  ///
  /// Chacune achète un coup de plus sans un bloc de plus : là où une ronde
  /// demandait quatre blocs pour un coup, une tuile suffit. C'est le levier
  /// qui découple la longueur de la solution de la taille du board.
  final int stopTileBudget;


  Difficulty get tier => Difficulty.fromScalar(scalar);

  int get targetBlocks => (minBlocks + maxBlocks) ~/ 2;

  /// Construit la configuration correspondant à une difficulté continue.
  factory DifficultyConfig.fromScalar(double t, {int? stopTileBudget}) {
    final scalar = t.clamp(0.0, 1.0);

    final gridSize = switch (scalar) {
      < 0.16 => 4,
      < 0.40 => 5,
      < 0.70 => 6,
      _ => 7,
    };
    final cells = gridSize * gridSize;

    // La grille doit respirer, et rester lisible. Surtout : au-delà d'une
    // douzaine de blocs, les rondes qui font la difficulté se diluent — leur
    // coup supplémentaire pèse de moins en moins dans le rapport coups par
    // bloc. Un board plus grand n'est donc pas un board plus difficile.
    final density = _lerp(0.20, 0.34, scalar);
    final target = (density * cells).round();
    final spread = math.max(1, (cells * 0.05).round());

    final minBlocks = math.max(2, target - spread);
    final maxBlocks = math.min((cells * 0.5).floor(), target + spread);

    return DifficultyConfig(
      scalar: scalar,
      gridSize: gridSize,
      minBlocks: minBlocks,
      maxBlocks: math.max(minBlocks, maxBlocks),
      repositionRatio: _lerp(0.20, 1.60, scalar),
      maxExitableRatio: _lerp(0.70, 0.28, scalar),
      // Bornes calées sur ce que le générateur produit réellement : le score
      // plafonne avec la taille de grille, il ne monte pas indéfiniment.
      minScore: _lerp(0, 26, scalar),
      maxScore: _lerp(22, 62, scalar),
      // Aucune ronde sur un petit board : elle en occuperait toute la
      // surface, le rembobinage n'aurait plus rien à faire, et tous les
      // premiers niveaux se ressembleraient — ils étaient littéralement
      // identiques. Une seule ensuite, deux sur les grands.
      knotCount: target >= 14 ? 2 : (target >= 9 ? 1 : 0),
      stopTileBudget: stopTileBudget ?? _lerp(0.6, 3.4, scalar).round(),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  String toString() => 'DifficultyConfig(${scalar.toStringAsFixed(2)} '
      '${gridSize}x$gridSize, $minBlocks-$maxBlocks blocs, '
      'repositionnement ${repositionRatio.toStringAsFixed(2)}, '
      'sorties immédiates <=${(maxExitableRatio * 100).round()}%, '
      '$knotCount ronde${knotCount > 1 ? 's' : ''}, '
      '$stopTileBudget tuile${stopTileBudget > 1 ? 's' : ''})';
}

/// Ce qu'on exige d'un niveau selon l'endroit où il tombe dans la campagne.
///
/// Le nombre de blocs ne fait pas la difficulté : un grand board dont chaque
/// bloc sort d'un tap reste facile. Ce qui compte est le rapport coups par
/// bloc, la part de blocs qu'il faut repositionner, et le nombre de décisions
/// réelles offertes en chemin.
class DifficultyBand {
  const DifficultyBand({
    required this.name,
    required this.upToLevel,
    required this.minComplexity,
    required this.maxComplexity,
    required this.minMultiMoveRatio,
    required this.minDecisionScore,
    required this.maxExitRatio,
  });

  final String name;
  final int upToLevel;

  /// Rapport coups / blocs visé.
  ///
  /// La borne haute ne vaut plus 1,25. Ce plafond n'était pas un réglage mais
  /// une conséquence des règles : sans tuile d'arrêt, un bloc n'est joué deux
  /// fois que pris dans un blocage circulaire, et le plus petit en compte
  /// quatre pour un seul coup gagné. La tuile lève cette contrainte — un coup
  /// de plus n'y coûte plus quatre blocs.
  ///
  /// Les bornes ci-dessous sont donc **provisoires** et volontairement
  /// larges : les vraies viendront de la distribution mesurée, pas d'une
  /// intuition posée avant de compter.
  final double minComplexity;
  final double maxComplexity;

  /// Part minimale de blocs qu'il faut jouer plusieurs fois.
  final double minMultiMoveRatio;

  /// Note de décision minimale, de 0 à 100.
  final double minDecisionScore;

  /// Part maximale de blocs qui peuvent sortir dès le premier coup.
  final double maxExitRatio;
}

/// La campagne, par tranches.
///
/// Les cinq premiers niveaux apprennent, les dix suivants laissent faire, et
/// c'est vers le trentième que le joueur doit commencer à pouvoir se tromper.
const List<DifficultyBand> difficultyBands = [
  DifficultyBand(
    name: 'Tutorial',
    upToLevel: 5,
    minComplexity: 1.0,
    maxComplexity: 99,
    minMultiMoveRatio: 0,
    minDecisionScore: 0,
    maxExitRatio: 1.0,
  ),
  DifficultyBand(
    name: 'Very easy',
    upToLevel: 15,
    minComplexity: 1.0,
    maxComplexity: 99,
    minMultiMoveRatio: 0,
    minDecisionScore: 30,
    maxExitRatio: 0.60,
  ),
  DifficultyBand(
    name: 'Easy',
    upToLevel: 30,
    minComplexity: 1.08,
    maxComplexity: 99,
    minMultiMoveRatio: 0.10,
    minDecisionScore: 50,
    maxExitRatio: 0.40,
  ),
  DifficultyBand(
    name: 'Easy / Medium',
    upToLevel: 50,
    minComplexity: 1.12,
    maxComplexity: 99,
    minMultiMoveRatio: 0.15,
    minDecisionScore: 62,
    maxExitRatio: 0.30,
  ),
  DifficultyBand(
    name: 'Medium',
    upToLevel: 100,
    minComplexity: 1.15,
    maxComplexity: 99,
    minMultiMoveRatio: 0.20,
    minDecisionScore: 72,
    maxExitRatio: 0.25,
  ),
  DifficultyBand(
    name: 'Medium / Hard',
    upToLevel: 250,
    minComplexity: 1.18,
    maxComplexity: 99,
    minMultiMoveRatio: 0.25,
    minDecisionScore: 80,
    maxExitRatio: 0.20,
  ),
  DifficultyBand(
    name: 'Hard',
    upToLevel: 1 << 30,
    minComplexity: 1.20,
    maxComplexity: 99,
    minMultiMoveRatio: 0.28,
    minDecisionScore: 86,
    maxExitRatio: 0.18,
  ),
];

DifficultyBand bandFor(int levelId) {
  for (final band in difficultyBands) {
    if (levelId <= band.upToLevel) return band;
  }
  return difficultyBands.last;
}

/// Courbe de progression : quelle difficulté pour quel numéro de niveau.
///
/// Deux idées s'y superposent. Une montée régulière qui sature, pour ne jamais
/// devenir injouable ; et une respiration, pour qu'un niveau difficile soit
/// suivi d'un plus simple. Une difficulté toujours croissante fatigue.
class DifficultyCurve {
  const DifficultyCurve._();

  /// Amplitude de la respiration, par position dans le cycle.
  static const List<double> _wave = [
    -0.05,
    -0.01,
    0.03,
    0.07,
    0.11,
    -0.08,
    0.01,
  ];

  /// Vitesse de montée : plus la valeur est grande, plus la courbe est douce.
  static const double _rampLength = 90;

  static double scalarFor(int levelId) {
    if (levelId <= 3) return 0;
    final base = 1 - math.exp(-(levelId - 3) / _rampLength);
    final wave = _wave[(levelId - 1) % _wave.length];
    return (base + wave).clamp(0.0, 1.0);
  }


  static DifficultyConfig configFor(int levelId) =>
      DifficultyConfig.fromScalar(scalarFor(levelId));

  static Difficulty tierFor(int levelId) =>
      Difficulty.fromScalar(scalarFor(levelId));
}
