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
    this.maxWalls = 0,
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

  /// Nombre de murs à poser. Ils arrivent tard dans la progression : la règle
  /// de base doit être acquise avant qu'on y ajoute des obstacles.
  final int maxWalls;

  Difficulty get tier => Difficulty.fromScalar(scalar);

  int get targetBlocks => (minBlocks + maxBlocks) ~/ 2;

  /// Construit la configuration correspondant à une difficulté continue.
  factory DifficultyConfig.fromScalar(double t, {int maxWalls = 0}) {
    final scalar = t.clamp(0.0, 1.0);

    final gridSize = switch (scalar) {
      < 0.16 => 4,
      < 0.40 => 5,
      < 0.70 => 6,
      _ => 7,
    };
    final cells = gridSize * gridSize;

    // La grille doit respirer : au-delà de la moitié des cases occupées, plus
    // rien ne glisse et le board se fige.
    final density = _lerp(0.20, 0.42, scalar);
    final target = (density * cells).round();
    final spread = math.max(1, (cells * 0.05).round());

    final minBlocks = math.max(2, target - spread);
    final maxBlocks = math.min((cells * 0.5).floor(), target + spread);

    return DifficultyConfig(
      scalar: scalar,
      gridSize: gridSize,
      minBlocks: minBlocks,
      maxBlocks: math.max(minBlocks, maxBlocks),
      repositionRatio: _lerp(0.15, 1.05, scalar),
      maxExitableRatio: _lerp(0.70, 0.28, scalar),
      // Bornes calées sur ce que le générateur produit réellement : le score
      // plafonne avec la taille de grille, il ne monte pas indéfiniment.
      minScore: _lerp(0, 26, scalar),
      maxScore: _lerp(22, 62, scalar),
      maxWalls: maxWalls,
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  String toString() => 'DifficultyConfig(${scalar.toStringAsFixed(2)} '
      '${gridSize}x$gridSize, $minBlocks-$maxBlocks blocs, '
      'repositionnement ${repositionRatio.toStringAsFixed(2)}, '
      'sorties immédiates <=${(maxExitableRatio * 100).round()}%'
      '${maxWalls > 0 ? ', $maxWalls mur${maxWalls > 1 ? 's' : ''}' : ''})';
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

  /// Nombre de murs par palier de progression.
  ///
  /// Les murs n'apparaissent qu'une fois la règle de base assimilée, et
  /// restent rares : ils ferment le board, et un board fermé se lit mal.
  static const List<({int upToLevel, int walls})> _wallPlan = [
    (upToLevel: 15, walls: 0),
    (upToLevel: 30, walls: 1),
    (upToLevel: 50, walls: 2),
  ];

  /// Au-delà du plan, on ajoute un mur sur les grandes grilles.
  static const int _wallsBeyondPlan = 3;

  static int wallsFor(int levelId, int gridSize) {
    for (final step in _wallPlan) {
      if (levelId <= step.upToLevel) return step.walls;
    }
    return gridSize >= 7 ? _wallsBeyondPlan + 1 : _wallsBeyondPlan;
  }

  static DifficultyConfig configFor(int levelId) {
    final scalar = scalarFor(levelId);
    final base = DifficultyConfig.fromScalar(scalar);
    return DifficultyConfig.fromScalar(
      scalar,
      maxWalls: wallsFor(levelId, base.gridSize),
    );
  }

  static Difficulty tierFor(int levelId) =>
      Difficulty.fromScalar(scalarFor(levelId));
}
