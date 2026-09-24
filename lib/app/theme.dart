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

  static const Color background = Color(0xFF8E44AD); // Wisteria

  /// Panneaux, cases vides, boutons secondaires.
  ///
  /// Amethyst est à Wisteria ce que Wet Asphalt était à Midnight Blue : la
  /// nuance juste au-dessus, assez proche pour ne pas découper la grille,
  /// assez distincte pour qu'une case vide se lise comme un emplacement.
  static const Color surface = Color(0xFF9B59B6); // Amethyst

  static const Color onBackground = Color(0xFFECF0F1); // Clouds
  static const Color onBackgroundSoft = Color(0xFFBDC3C7); // Silver
  static const Color onBackgroundFaint = Color(0xFF95A5A6); // Concrete

  static const Color accent = Color(0xFF3498DB); // Peter River
  static const Color danger = Color(0xFFE74C3C); // Alizarin
  static const Color success = Color(0xFF2ECC71); // Emerald

  /// Texte posé sur une surface claire.
  static const Color ink = Color(0xFF2C3E50);

  /// Les huit couleurs de blocs.
  ///
  /// Aucune ne désigne une direction : la flèche s'en charge seule. La couleur
  /// n'a donc aucune fonction de jeu, elle casse la monotonie de la grille —
  /// et un joueur daltonien ne joue pas moins bien qu'un autre.
  /// Amethyst n'en fait plus partie : il sert désormais aux cases vides, et un
  /// bloc de la même teinte que le plateau se verrait mal.
  static const List<Color> blocks = [
    Color(0xFF1ABC9C), // Turquoise
    Color(0xFF2ECC71), // Emerald
    Color(0xFF3498DB), // Peter River
    Color(0xFFF1C40F), // Sun Flower
    Color(0xFFE67E22), // Carrot
    Color(0xFFE74C3C), // Alizarin
    Color(0xFF2980B9), // Belize Hole
    Color(0xFF16A085), // Green Sea
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
    return blocks[hash % blocks.length];
  }

  /// Flèche : la couleur du fond, pas du noir pur. Elle creuse le bloc au lieu
  /// de le trouer.
  static const Color arrow = Color(0xFF2C3E50);
}

class UngridTheme {
  const UngridTheme._();

  static ThemeData build() {
    const base = ColorScheme.dark(
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
