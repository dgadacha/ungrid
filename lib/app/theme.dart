import 'package:flutter/material.dart';

/// Direction artistique : fond nuit, blocs francs, aucun effet.
///
/// Pas de dégradé, pas de texture, pas de reflet. Un aplat de couleur, un
/// arrondi, une flèche épaisse : ce que le joueur doit lire, il le lit du
/// premier coup d'oeil, et la grille reste calme même bien remplie.
class UngridColors {
  const UngridColors._();

  // Palette Flat UI v1. Les noms d'origine sont conservés en commentaire :
  // c'est la référence à rouvrir pour toute retouche.

  /// Fond de l'application. Se change dans les réglages.
  static Color background = UngridBackground.wisteria.background;

  /// Panneaux, cases vides, boutons secondaires.
  ///
  /// Toujours la nuance juste au-dessus du fond, comme Amethyst l'est à
  /// Wisteria : assez proche pour ne pas découper la grille, assez distincte
  /// pour qu'une case vide se lise comme un emplacement.
  static Color surface = UngridBackground.wisteria.surface;

  /// Applique un fond, sa nuance de surface et l'accent qui va avec.
  static void apply(UngridBackground choice) {
    background = choice.background;
    surface = choice.surface;
    accent = choice.accent;
  }

  static const Color onBackground = Color(0xFFECF0F1); // Clouds
  static const Color onBackgroundSoft = Color(0xFFBDC3C7); // Silver
  static const Color onBackgroundFaint = Color(0xFF95A5A6); // Concrete

  /// Sélection, mise en avant, bordure du niveau courant.
  ///
  /// Il suit le fond choisi : un accent de la couleur des cases vides ne
  /// désignerait plus rien, donc il s'écarte quand le plateau prend sa teinte.
  static Color accent = UngridBackground.wisteria.accent;
  static const Color danger = Color(0xFFE74C3C); // Alizarin
  static const Color success = Color(0xFF2ECC71); // Emerald

  /// Texte posé sur une surface claire.
  static const Color ink = Color(0xFF2C3E50);

  /// L'encre des flèches, la même sur tous les blocs.
  ///
  /// Une seule teinte pour toutes les directions : aucune couleur ne désigne
  /// un sens, c'est la forme qui le fait, et un joueur daltonien ne joue pas
  /// moins bien qu'un autre.
  static const Color arrow = Color(0xFF2C3E50); // Midnight Blue

  /// Les six aplats de blocs.
  static const List<Color> blocks = [
    Color(0xFF2ECC71), // Emerald
    Color(0xFF3498DB), // Peter River
    Color(0xFF9B59B6), // Amethyst
    Color(0xFFF1C40F), // Sun Flower
    Color(0xFFE67E22), // Carrot
    Color(0xFFE74C3C), // Alizarin
  ];

  /// Couleur d'un bloc, tirée de son identité et non de sa case.
  ///
  /// Les blocs se déplacent : une couleur attachée à la position les ferait
  /// changer de teinte en glissant, ce qui rendrait la grille illisible.
  static Color blockFor(String blockId) {
    var hash = 0;
    for (final unit in blockId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    hash = (hash ^ (hash >> 13)) & 0x7FFFFFFF;
    // La teinte du plateau est retirée du tirage : un bloc de la couleur des
    // cases vides disparaîtrait dedans.
    final choices = [
      for (final color in blocks)
        if (color != surface) color,
    ];
    return choices[hash % choices.length];
  }
}

class UngridTheme {
  const UngridTheme._();

  static ThemeData build() {
    // Plus constant : la surface suit le fond choisi dans les réglages.
    final base = ColorScheme.dark(
      primary: UngridColors.accent,
      secondary: UngridColors.accent,
      surface: UngridColors.surface,
      onSurface: UngridColors.onBackground,
      error: UngridColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'NunitoSans',
      colorScheme: base,
      scaffoldBackgroundColor: UngridColors.background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 46,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
          color: UngridColors.onBackground,
        ),
        displayMedium: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          color: UngridColors.onBackground,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          color: UngridColors.onBackground,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          color: UngridColors.onBackground,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: UngridColors.onBackgroundSoft,
        ),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.4,
          color: UngridColors.onBackgroundSoft,
        ),
      ),
    );
  }
}

/// Les fonds proposés dans les réglages.
///
/// Chacun est une paire de la palette Flat UI : la teinte sombre pour le
/// fond, sa voisine claire pour les cases vides. Ce sont les couples
/// d'origine de la palette, pas des variantes calculées — c'est ce qui fait
/// qu'un plateau reste lisible quelle que soit la couleur choisie.
enum UngridBackground {
  belizeHole(Color(0xFF2980B9), Color(0xFF3498DB), Color(0xFF9B59B6)),
  wisteria(Color(0xFF8E44AD), Color(0xFF9B59B6), Color(0xFF3498DB)),
  midnight(Color(0xFF2C3E50), Color(0xFF34495E), Color(0xFF3498DB));

  const UngridBackground(this.background, this.surface, this.accent);

  /// La nuance du plateau est toujours la teinte juste au-dessus du fond :
  /// une case vide se lit comme un emplacement, pas comme une découpe.
  final Color background;
  final Color surface;

  /// L'accent ne reprend jamais la couleur des cases vides, sinon une
  /// sélection deviendrait invisible sur ce fond.
  final Color accent;

  static UngridBackground fromName(String? name) =>
      UngridBackground.values.firstWhere(
        (choice) => choice.name == name,
        orElse: () => UngridBackground.wisteria,
      );
}
