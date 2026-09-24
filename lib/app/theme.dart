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

  /// Applique un fond et les teintes de signalisation qui vont avec.
  static void apply(UngridBackground choice) {
    background = choice.background;
    surface = choice.surface;
    accent = choice.accent;
    success = choice.success;
    danger = choice.danger;
    onBackground = choice.onBackground;
    onBackgroundSoft = choice.onBackgroundSoft;
    onBackgroundFaint = choice.onBackgroundFaint;
  }

  /// Le texte posé sur le fond, du plus franc au plus discret.
  ///
  /// Clair sur les fonds sombres, encre sur les fonds clairs : sur Orange, du
  /// blanc cassé tomberait à 1,9 de contraste et les libellés disparaîtraient.
  static Color onBackground = UngridBackground.wisteria.onBackground;
  static Color onBackgroundSoft = UngridBackground.wisteria.onBackgroundSoft;
  static Color onBackgroundFaint = UngridBackground.wisteria.onBackgroundFaint;

  // Les trois teintes de signalisation suivent le fond choisi : une couleur
  // qui tombe sur celle des cases vides ne désigne plus rien. Le tableau des
  // fonds, plus bas, dit laquelle s'écarte et vers quoi.

  /// Sélection, mise en avant, bordure du niveau courant.
  static Color accent = UngridBackground.wisteria.accent;

  /// Effacement, coups qui manquent, pièce inutile.
  static Color danger = UngridBackground.wisteria.danger;

  /// Niveau réussi, maîtrise, progression.
  static Color success = UngridBackground.wisteria.success;

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
      textTheme: TextTheme(
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

// La palette Flat UI « defo », par couples : la teinte claire et sa voisine
// sombre. Nommer les couleurs rend le tableau des fonds lisible d'un coup.
const Color _turquoise = Color(0xFF1ABC9C);
const Color _greenSea = Color(0xFF16A085);
const Color _emerald = Color(0xFF2ECC71);
const Color _nephritis = Color(0xFF27AE60);
const Color _peterRiver = Color(0xFF3498DB);
const Color _belizeHole = Color(0xFF2980B9);
const Color _amethyst = Color(0xFF9B59B6);
const Color _wisteria = Color(0xFF8E44AD);
const Color _wetAsphalt = Color(0xFF34495E);
const Color _midnight = Color(0xFF2C3E50);
const Color _sunFlower = Color(0xFFF1C40F);
const Color _orange = Color(0xFFF39C12);
const Color _carrot = Color(0xFFE67E22);
const Color _pumpkin = Color(0xFFD35400);
const Color _alizarin = Color(0xFFE74C3C);
const Color _pomegranate = Color(0xFFC0392B);
const Color _clouds = Color(0xFFECF0F1);
const Color _silver = Color(0xFFBDC3C7);
const Color _concrete = Color(0xFF95A5A6);

/// Midnight assez dilué pour jouer le rôle de Concrete sur un fond clair.
const Color _midnightFaint = Color(0x732C3E50);

/// Les fonds proposés dans les réglages.
///
/// Chacun est une paire de la palette Flat UI : la teinte sombre pour le
/// fond, sa voisine claire pour les cases vides. Ce sont les couples
/// d'origine de la palette, pas des variantes calculées — c'est ce qui fait
/// qu'un plateau reste lisible quelle que soit la couleur choisie.
enum UngridBackground {
  greenSea(_greenSea, _turquoise, accent: _amethyst),
  nephritis(_nephritis, _emerald, success: _turquoise),
  belizeHole(_belizeHole, _peterRiver, accent: _amethyst),
  wisteria(_wisteria, _amethyst),
  midnight(_midnight, _wetAsphalt),
  orange(_orange, _sunFlower, ink: true),
  pumpkin(_pumpkin, _carrot),
  pomegranate(_pomegranate, _alizarin, danger: _carrot);

  const UngridBackground(
    this.background,
    this.surface, {
    this.accent = _peterRiver,
    this.success = _emerald,
    this.danger = _alizarin,
    this.ink = false,
  });

  /// Vrai quand le fond est assez clair pour que le texte passe à l'encre
  /// sombre. Un fond clair avec du blanc cassé ne se lit pas.
  final bool ink;

  Color get onBackground => ink ? _midnight : _clouds;
  Color get onBackgroundSoft => ink ? _wetAsphalt : _silver;
  Color get onBackgroundFaint => ink ? _midnightFaint : _concrete;

  /// La nuance du plateau est toujours la teinte juste au-dessus du fond :
  /// une case vide se lit comme un emplacement, pas comme une découpe.
  final Color background;
  final Color surface;

  /// Les trois teintes de signalisation. Chacune garde sa valeur habituelle,
  /// sauf sur le fond qui lui prend sa couleur : sur Nephritis les cases vides
  /// sont déjà Emerald, donc la réussite passe à Turquoise, et ainsi de suite.
  final Color accent;
  final Color success;
  final Color danger;

  static UngridBackground fromName(String? name) =>
      UngridBackground.values.firstWhere(
        (choice) => choice.name == name,
        orElse: () => UngridBackground.wisteria,
      );
}
