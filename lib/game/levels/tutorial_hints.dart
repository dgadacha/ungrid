/// Les phrases qui accompagnent les premiers niveaux.
///
/// Elles sont attachées au numéro du niveau, pas à un board fabriqué à la
/// main : les grilles viennent toutes du générateur, seule la phrase est
/// écrite. Au-delà, plus rien ne s'affiche — on apprend en jouant.
class TutorialHints {
  const TutorialHints._();

  static String? forLevel(int levelId) => switch (levelId) {
        1 => 'Tap a block: it leaves the way its arrow points.',
        2 => 'A block slides until something stops it.',
        3 => 'Stuck against an obstacle, it stays put — and the move is spent.',
        4 => 'A block landing on a dot stops there. Tap it again to go on.',
        _ => null,
      };
}
