/// Réglages de temps et de forme, rassemblés pour être ajustés d'un seul
/// endroit. Le jeu se joue à la seconde : ces valeurs décident de sa nervosité.
class GameTiming {
  const GameTiming._();

  /// Sortie d'un bloc : assez rapide pour paraître éjecté, assez longue pour
  /// qu'on la voie.
  static const Duration blockExit = Duration(milliseconds: 210);

  /// Refus : un aller-retour sec, qui dit « non » sans faire attendre.
  static const Duration blockedShake = Duration(milliseconds: 130);

  /// Le « bonk » reste lisible un peu après la secousse, sans jamais retarder
  /// le coup suivant.
  static const Duration blockedLabel = Duration(milliseconds: 320);

  /// Enfoncement au doigt, joué en même temps que le reste.
  static const Duration tapPress = Duration(milliseconds: 90);

  /// Respiration avant l'annonce de la victoire.
  static const Duration clearDelay = Duration(milliseconds: 300);

  /// Impulsion du board quand le dernier bloc sort.
  static const Duration boardPulse = Duration(milliseconds: 420);

  /// Apparition de l'écran de victoire.
  static const Duration overlayFade = Duration(milliseconds: 260);

  /// Changement d'écran.
  static const Duration screenTransition = Duration(milliseconds: 220);

  /// Sursaut du compteur de coups à chaque changement.
  static const Duration counterPulse = Duration(milliseconds: 220);

  /// Surdité de la grille juste après une transition, le temps que le geste
  /// qui l'a déclenchée se termine.
  static const Duration inputLock = Duration(milliseconds: 260);
}

class GameMetrics {
  const GameMetrics._();

  /// Arrondi des blocs, proportionnel à la taille de cellule.
  static const double blockRadiusRatio = 0.20;

  /// Espace entre deux blocs, proportionnel à la taille de cellule.
  static const double blockInsetRatio = 0.055;

  /// Taille de la flèche dans son bloc.
  static const double arrowSizeRatio = 0.60;

  /// Écrasement du bloc au moment du tap.
  static const double pressScale = 0.94;

  /// Marge autour de la grille, en points.
  static const double boardPadding = 20;
}
