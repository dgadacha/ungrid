/// Paliers de difficulté, utilisés pour l'UI, le debug et le paramétrage du
/// générateur. La difficulté réelle est un scalaire continu ; ces paliers en
/// sont une lecture lisible.
enum Difficulty {
  easy,
  medium,
  hard,
  expert;

  String get label => switch (this) {
        Difficulty.easy => 'EASY',
        Difficulty.medium => 'MEDIUM',
        Difficulty.hard => 'HARD',
        Difficulty.expert => 'EXPERT',
      };

  static Difficulty fromScalar(double t) {
    if (t < 0.30) return Difficulty.easy;
    if (t < 0.55) return Difficulty.medium;
    if (t < 0.80) return Difficulty.hard;
    return Difficulty.expert;
  }
}
