/// Paliers de difficulté, utilisés pour l'UI, le debug et le paramétrage du
/// générateur. La difficulté réelle est un scalaire continu ; ces paliers en
/// sont une lecture lisible.
enum Difficulty {
  easy,
  medium,
  hard,
  expert;

  String get label => switch (this) {
        Difficulty.easy => 'FACILE',
        Difficulty.medium => 'MOYEN',
        Difficulty.hard => 'DIFFICILE',
        Difficulty.expert => 'EXPERT',
      };

  static Difficulty fromScalar(double t) {
    if (t < 0.30) return Difficulty.easy;
    if (t < 0.55) return Difficulty.medium;
    if (t < 0.80) return Difficulty.hard;
    return Difficulty.expert;
  }
}

/// Marge d'erreur accordée au joueur, en coups, au-delà de la solution
/// minimale.
///
/// C'est le levier d'équilibrage principal du jeu : le solveur donne le nombre
/// de coups strictement nécessaires, et cette marge décide de la pression.
/// Une même grille devient nettement plus exigeante avec deux coups de marge
/// qu'avec cinq, sans qu'on ait à toucher au board.
const Map<Difficulty, int> moveAllowanceByDifficulty = {
  Difficulty.easy: 5,
  Difficulty.medium: 4,
  Difficulty.hard: 3,
  Difficulty.expert: 2,
};

int moveAllowanceFor(Difficulty difficulty) =>
    moveAllowanceByDifficulty[difficulty] ?? 3;
