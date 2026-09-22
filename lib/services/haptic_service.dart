import 'package:flutter/services.dart';

/// Retours haptiques du jeu.
///
/// Quatre sensations distinctes, jamais interchangeables : le bloc part, le
/// bloc refuse, la grille est vide, les coups sont épuisés.
class HapticService {
  HapticService({this.enabled = true});

  bool enabled;

  void blockExit() {
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
