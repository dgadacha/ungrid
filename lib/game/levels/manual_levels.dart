import '../models/difficulty.dart';
import '../models/level.dart';
import 'level_pattern.dart';

/// Les premiers niveaux, écrits à la main.
///
/// Ils portent l'apprentissage : chacun introduit une idée et une seule.
/// 1 le geste, 2 le glissement, 3 le refus, 4 le repositionnement, puis les
/// dépendances, les quatre directions, le choix, et les premiers vrais
/// puzzles. Au-delà, le générateur prend le relais.
///
/// Tous sont validés par `LevelSolver` dans les tests.
class ManualLevels {
  const ManualLevels._();

  static const int count = 22;

  static bool contains(int levelId) => levelId >= 1 && levelId <= count;

  static Level byId(int levelId) {
    final pattern = _patterns[levelId - 1];
    return LevelPattern.parse(
      pattern.$1,
      id: levelId,
      difficulty: pattern.$2,
    );
  }

  static List<Level> all() =>
      [for (var i = 1; i <= count; i++) byId(i)];

  /// Phrase affichée sous la grille pendant l'apprentissage.
  ///
  /// Une idée par niveau, dite une fois. Le joueur apprend en jouant : ces
  /// lignes accompagnent le geste, elles ne le remplacent pas.
  static String? hintFor(int levelId) => switch (levelId) {
        1 => 'Touche un bloc : il part dans le sens de sa flèche.',
        2 => 'Un bloc glisse jusqu\'à ce que quelque chose l\'arrête.',
        3 => 'Collé à un obstacle, il ne bouge pas — et le coup est perdu.',
        4 => 'Ici, rien ne peut sortir. Pousse d\'abord un bloc.',
        _ => null,
      };

  /// Grilles et difficulté affichée.
  static const List<(List<String>, Difficulty)> _patterns = [
    // 1 — Un bloc, une sortie. Tout le jeu tient là.
    ([
      '....',
      '....',
      '.>..',
      '....',
    ], Difficulty.easy),

    // 2 — Le glissement : le bloc avance et s'arrête devant l'obstacle.
    ([
      '....',
      '>..^',
      '....',
      '....',
    ], Difficulty.easy),

    // 3 — Le refus : collé à son voisin, le bloc ne bouge pas.
    ([
      '....',
      '>^..',
      '....',
      '....',
    ], Difficulty.easy),

    // 4 — Personne ne peut sortir : il faut d'abord pousser.
    ([
      '>.v.',
      '....',
      '....',
      '^.<.',
    ], Difficulty.easy),

    // 5 — Une chaîne : l'ordre devient la question.
    ([
      '..<.',
      '>.^.',
      '....',
      '....',
    ], Difficulty.easy),

    // 6 — Deux blocs retiennent le même : la convergence.
    ([
      '>v.v',
      '....',
      '..<.',
      '..^.',
    ], Difficulty.easy),

    // 7 — Deux fils indépendants.
    ([
      '..<.',
      '>.^.',
      '....',
      '.v.^',
    ], Difficulty.easy),

    // 8 — La chaîne s'allonge.
    ([
      '.<..',
      '>..^',
      '.^..',
      '.>.^',
    ], Difficulty.easy),

    // 9 — Peu d'ouvertures, une longue séquence.
    ([
      '.v.<',
      '>..^',
      '.<.^',
      '..>.',
    ], Difficulty.easy),

    // 10 — Le passage en 5x5.
    ([
      '..v..',
      '.....',
      '>...^',
      '..<..',
      '.^..<',
    ], Difficulty.easy),

    // 11 — Le passage en 5x5 : plus d'espace, mêmes règles.
    ([
      '..>^.',
      'v....',
      '...<.',
      '....>',
      '>..^.',
    ], Difficulty.easy),

    // 12 — Deux fils se croisent.
    ([
      '>.v^.',
      '.....',
      '...^.',
      '^....',
      '.v.^<',
    ], Difficulty.easy),

    // 13 — Il faut ouvrir avant de vider.
    ([
      '>.>^v',
      '.v...',
      '.....',
      '.v..<',
      '..^..',
    ], Difficulty.easy),

    // 14 — Le board se lit en entier.
    ([
      '.<.v.',
      '>^...',
      '...>.',
      '.^.v<',
      '.^...',
    ], Difficulty.easy),

    // 15 — Plusieurs départs, une seule direction utile.
    ([
      '....^',
      '>>^.>',
      '.....',
      '^.^<<',
      '..^..',
    ], Difficulty.medium),

    // 16 — Le coin haut gauche tient tout le reste.
    ([
      '<^<<v',
      '.^...',
      '....v',
      '^^..<',
      '.<..<',
    ], Difficulty.medium),

    // 17 — Les rangées se libèrent l'une après l'autre.
    ([
      '..v<.',
      '>>.>^',
      '^....',
      '>.>.>',
      '^.v.<',
    ], Difficulty.medium),

    // 18 — Huit couches à démêler.
    ([
      '..<v.',
      '>>^.v',
      '...v.',
      '.^..>',
      '.v^<<',
    ], Difficulty.medium),

    // 19 — Premier vrai puzzle, en 6x6.
    ([
      '<v.<.<',
      '..v...',
      '>..^..',
      '^v>.>.',
      '...^..',
      '^..^..',
    ], Difficulty.medium),

    // 20 — Large, mais peu d'ouvertures.
    ([
      '..v...',
      '.v<<^.',
      '.>..>.',
      '..v.^<',
      '^<<..<',
      '....^.',
    ], Difficulty.hard),

    // 21 — Neuf couches : il faut anticiper.
    ([
      '>.>>v^',
      '.v..<<',
      '...^..',
      '^.....',
      '>..^.^',
      '^.<^.>',
    ], Difficulty.hard),

    // 22 — La porte de sortie vers le générateur.
    ([
      '..v<v<',
      '>.>...',
      'v....>',
      'v.....',
      '>..>.v',
      '>>.^>v',
    ], Difficulty.hard),
  ];
}
