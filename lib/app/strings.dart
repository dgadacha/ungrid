import 'package:flutter/widgets.dart';

/// Les langues proposées.
enum AppLanguage {
  en('English', 'en'),
  fr('Français', 'fr'),
  es('Español', 'es');

  const AppLanguage(this.label, this.code);

  /// Nom de la langue, écrit dans cette langue : c'est ainsi qu'on la
  /// reconnaît quand on ne comprend pas celle affichée.
  final String label;
  final String code;

  static AppLanguage fromCode(String? code) =>
      AppLanguage.values.firstWhere(
        (language) => language.code == code,
        orElse: () => AppLanguage.en,
      );
}

/// Les textes de l'interface, dans les trois langues.
///
/// Pas de fichiers de ressources ni de génération de code : l'interface tient
/// en une cinquantaine de phrases, et les voir côte à côte vaut mieux que de
/// les chercher dans trois fichiers séparés — une traduction oubliée se
/// repère à l'oeil.
class Strings {
  const Strings(this.language);

  final AppLanguage language;

  /// Les textes pour le contexte courant, anglais par défaut.
  ///
  /// Un widget monté hors de l'application — un test, un aperçu — n'a pas de
  /// langue au-dessus de lui. Mieux vaut lui répondre en anglais que le faire
  /// échouer sur un réglage qui ne le concerne pas.
  static Strings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()?.strings ??
      const Strings(AppLanguage.en);

  String _pick(String en, String fr, String es) => switch (language) {
        AppLanguage.en => en,
        AppLanguage.fr => fr,
        AppLanguage.es => es,
      };

  // ── Accueil ────────────────────────────────────────────────────────────
  String get play => _pick('PLAY', 'JOUER', 'JUGAR');
  String get replay => _pick('REPLAY', 'REJOUER', 'REPETIR');
  String get rewards => _pick('REWARDS', 'RÉCOMPENSES', 'RECOMPENSAS');
  String get levels => _pick('LEVELS', 'NIVEAUX', 'NIVELES');
  String get campaignComplete =>
      _pick('CAMPAIGN COMPLETE', 'CAMPAGNE TERMINÉE', 'CAMPAÑA COMPLETA');

  String level(int id) => _pick('LEVEL $id', 'NIVEAU $id', 'NIVEL $id');
  String chapter(int id) =>
      _pick('CHAPTER $id', 'CHAPITRE $id', 'CAPÍTULO $id');
  String chapterProgress(int id, int cleared) => _pick(
        'CHAPTER $id · $cleared/10 SOLVED',
        'CHAPITRE $id · $cleared/10 RÉSOLUS',
        'CAPÍTULO $id · $cleared/10 RESUELTOS',
      );

  String get campaignChanged => _pick(
        'New challenge campaign. Your previous save has been kept separately.',
        'Nouvelle campagne. Votre ancienne sauvegarde est conservée à part.',
        'Nueva campaña. Tu partida anterior se ha guardado aparte.',
      );
  String get progressReset => _pick(
        'New levels: the puzzles changed, so progress and records were reset.',
        'Nouveaux niveaux : les grilles ont changé, progression et records '
            'sont remis à zéro.',
        'Niveles nuevos: las cuadrículas han cambiado, el progreso y los '
            'récords se han borrado.',
      );

  // ── Partie ─────────────────────────────────────────────────────────────
  String get movesLeft => _pick('MOVES LEFT', 'COUPS', 'MOVIMIENTOS');
  String get time => _pick('TIME', 'TEMPS', 'TIEMPO');
  String get undo => _pick('UNDO', 'ANNULER', 'DESHACER');
  String get restart => _pick('RESTART', 'RECOMMENCER', 'REINICIAR');
  String get hint => _pick('HINT', 'INDICE', 'PISTA');
  String get noHint => _pick(
        'No hint available right now.',
        'Aucun indice pour le moment.',
        'No hay ninguna pista ahora mismo.',
      );

  String get rotationRule => _pick(
        'Circular tiles stop the block and turn its arrow 90° clockwise.',
        'Les cases rondes arrêtent le bloc et tournent sa flèche d\'un quart '
            'de tour.',
        'Las casillas redondas detienen el bloque y giran su flecha 90°.',
      );
  String get fragileRule => _pick(
        'A cracked stop holds once, then breaks when the block leaves. '
            'Undo restores it.',
        'Une case fêlée retient une fois, puis se brise au départ du bloc. '
            'L\'annulation la rétablit.',
        'Una casilla agrietada retiene una vez y se rompe al salir el bloque. '
            'Deshacer la restaura.',
      );
  String get playtestBanner => _pick(
        'PLAYTEST · NOTHING IS SAVED',
        'ESSAI · RIEN N\'EST ENREGISTRÉ',
        'PRUEBA · NO SE GUARDA NADA',
      );

  /// Les phrases d'apprentissage des premiers niveaux.
  String? tutorial(int levelId) => switch (levelId) {
        1 => _pick(
            'Tap a block: it leaves the way its arrow points.',
            'Touchez un bloc : il part dans le sens de sa flèche.',
            'Toca un bloque: sale en la dirección de su flecha.',
          ),
        2 => _pick(
            'A block slides until something stops it.',
            'Un bloc glisse jusqu\'à ce que quelque chose l\'arrête.',
            'Un bloque se desliza hasta que algo lo detiene.',
          ),
        3 => _pick(
            'Stuck against an obstacle, it stays put — and the move is spent.',
            'Collé à un obstacle, il ne bouge pas — et le coup est perdu.',
            'Pegado a un obstáculo no se mueve, y el movimiento se pierde.',
          ),
        4 => _pick(
            'A block landing on a dot stops there. Tap it again to go on.',
            'Un bloc qui arrive sur un point s\'y arrête. Touchez-le à '
                'nouveau pour repartir.',
            'Un bloque que llega a un punto se detiene. Tócalo otra vez para '
                'seguir.',
          ),
        _ => null,
      };

  // ── Fin de partie ──────────────────────────────────────────────────────
  String get solved => _pick('SOLVED', 'RÉSOLU', 'RESUELTO');
  String get moves => _pick('MOVES', 'COUPS', 'MOVIMIENTOS');
  String get next => _pick('NEXT', 'SUIVANT', 'SIGUIENTE');
  String best(String value) =>
      _pick('BEST $value', 'RECORD $value', 'RÉCORD $value');
  String get newBestTime =>
      _pick('NEW BEST TIME', 'NOUVEAU RECORD', 'NUEVO RÉCORD');
  String get newBestMoves =>
      _pick('NEW BEST MOVES', 'MOINS DE COUPS', 'MENOS MOVIMIENTOS');
  String get doubleRecord =>
      _pick('DOUBLE RECORD', 'DOUBLE RECORD', 'DOBLE RÉCORD');
  String get mastered => _pick('MASTERED', 'MAÎTRISÉ', 'DOMINADO');
  String get clearedWithHelp => _pick(
        'Cleared with assistance',
        'Réussi avec de l\'aide',
        'Resuelto con ayuda',
      );
  String get masteryRule => _pick(
        'No hints. Original move budget.',
        'Sans indice, avec la réserve d\'origine.',
        'Sin pistas, con los movimientos originales.',
      );
  String get medalCollected => _pick(
        'CHAPTER MEDAL COLLECTED',
        'MÉDAILLE DU CHAPITRE',
        'MEDALLA DEL CAPÍTULO',
      );
  String get medalCollectedShort =>
      _pick('Medal collected', 'Médaille obtenue', 'Medalla obtenida');

  String get outOfMoves =>
      _pick('OUT OF MOVES', 'PLUS DE COUPS', 'SIN MOVIMIENTOS');
  String get retry => _pick('RETRY', 'RÉESSAYER', 'REINTENTAR');
  String get undoMove => _pick('UNDO MOVE', 'ANNULER LE COUP', 'DESHACER');
  String extraMoves(int count) =>
      _pick('+$count MOVES', '+$count COUPS', '+$count MOVIMIENTOS');

  // ── Réglages ───────────────────────────────────────────────────────────
  String get settings => _pick('SETTINGS', 'RÉGLAGES', 'AJUSTES');
  String get haptics => _pick('HAPTICS', 'VIBRATIONS', 'VIBRACIÓN');
  String get languageLabel => _pick('LANGUAGE', 'LANGUE', 'IDIOMA');
  String get resetProgress => _pick(
        'RESET PROGRESS',
        'EFFACER LA PROGRESSION',
        'BORRAR EL PROGRESO',
      );
  String progressSummary(int level, int cleared) => _pick(
        'Level $level · $cleared cleared',
        'Niveau $level · $cleared réussis',
        'Nivel $level · $cleared superados',
      );
  String get resetQuestion =>
      _pick('Reset progress?', 'Tout effacer ?', '¿Borrar el progreso?');
  String get resetWarning => _pick(
        'Cleared levels and best times will be lost.',
        'Les niveaux réussis et les records seront perdus.',
        'Se perderán los niveles superados y los récords.',
      );
  String get cancel => _pick('Cancel', 'Annuler', 'Cancelar');
  String get reset => _pick('Reset', 'Effacer', 'Borrar');

  // ── Récompenses ────────────────────────────────────────────────────────
  String get collection =>
      _pick('YOUR COLLECTION', 'VOTRE COLLECTION', 'TU COLECCIÓN');
  String get equip => _pick('EQUIP', 'CHOISIR', 'ELEGIR');
  String get equipped => _pick('EQUIPPED', 'EN COURS', 'EN USO');
  String get locked => _pick('LOCKED', 'À DÉBLOQUER', 'BLOQUEADO');
  String get alwaysAvailable =>
      _pick('Always available', 'Toujours disponible', 'Siempre disponible');
  String get rewardsRule => _pick(
        'Solve a chapter to earn its medal. Master every level to turn it '
            'gold. Undo is always allowed.',
        'Terminez un chapitre pour gagner sa médaille. Maîtrisez tous ses '
            'niveaux pour la passer en or. L\'annulation reste permise.',
        'Completa un capítulo para ganar su medalla. Domina todos sus niveles '
            'para volverla dorada. Deshacer siempre está permitido.',
      );
  String chapterMastery(int id, int cleared, int mastered) => _pick(
        'Chapter $id · $cleared/10 solved · $mastered/10 mastered',
        'Chapitre $id · $cleared/10 réussis · $mastered/10 maîtrisés',
        'Capítulo $id · $cleared/10 superados · $mastered/10 dominados',
      );
}

/// Porte la langue choisie jusqu'aux écrans.
///
/// Changer de langue reconstruit tout l'arbre : c'est un réglage qu'on touche
/// une fois, pas une animation, et cela évite d'avoir à propager l'objet à la
/// main dans chaque écran.
class LanguageScope extends InheritedWidget {
  const LanguageScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final Strings strings;

  @override
  bool updateShouldNotify(LanguageScope old) =>
      old.strings.language != strings.language;
}
