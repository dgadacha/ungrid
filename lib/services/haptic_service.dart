import 'package:flutter/services.dart';

/// Retours haptiques du jeu.
///
/// Cinq événements pour quatre sensations : le bloc part, le bloc se pose sur
/// une tuile, le bloc refuse, la grille est vide, les coups sont épuisés. Le
/// départ et la pose partagent l'impulsion légère — ce sont les deux façons
/// dont un déplacement aboutit ; le refus, lui, ne leur ressemble jamais.
class HapticService {
  HapticService({this.enabled = true});

  bool enabled;

  void blockExit() {
    if (enabled) HapticFeedback.lightImpact();
  }

  void stoppedOnTile() {
    if (enabled) HapticFeedback.lightImpact();
  }

  void blocked() {
    if (enabled) HapticFeedback.selectionClick();
  }

  void levelClear() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  void gameOver() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}
