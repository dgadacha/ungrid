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

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
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
  String get levels => _pick('LEVELS', 'NIVEAUX', 'NIVELES');

  /// Le compteur du bas de l'accueil.
  ///
  /// L'accord se fait dans chaque langue plutôt qu'en collant un « s » : le
  /// pluriel espagnol ne s'écrit pas comme l'anglais, et le français accorde
  /// aussi le participe.
  String levelsCleared(int count) => _pick(
    '$count LEVEL${count > 1 ? 'S' : ''} CLEARED',
    '$count NIVEAU${count > 1 ? 'X' : ''} RÉUSSI${count > 1 ? 'S' : ''}',
    '$count NIVEL${count > 1 ? 'ES' : ''} SUPERADO${count > 1 ? 'S' : ''}',
  );
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

  /// Le cri du refus, lâché au-dessus d'un bloc qui n'a pas bougé.
  String get bonk => _pick('BONK !', 'BLOQUÉ !', '¡BLOQUEADO!');
  String get noHint => _pick(
    'No hint available right now.',
    'Aucun indice pour le moment.',
    'No hay ninguna pista ahora mismo.',
  );

  // ── Récompense par publicité ────────────────────────────────────────────
  // La modale dit la règle plutôt que le prix : « la première est offerte »
  // se comprend une fois pour toutes, « regarder une pub » se subit à chaque
  // fois.
  String get undoAdTitle =>
      _pick('One more undo?', 'Encore une annulation ?', '¿Deshacer otra vez?');
  String get undoAdBody => _pick(
    'The first one is free every game. After that, it takes a short video.',
    'La première est offerte à chaque partie. Les suivantes passent par une '
        'courte vidéo.',
    'La primera es gratis en cada partida. Después hace falta un vídeo corto.',
  );
  String get hintAdTitle =>
      _pick('One more hint?', 'Encore un indice ?', '¿Otra pista?');
  String get hintAdBody => _pick(
    'The first one is free every game. After that, it takes a short video.',
    'Le premier est offert à chaque partie. Les suivants passent par une '
        'courte vidéo.',
    'La primera es gratis en cada partida. Después hace falta un vídeo corto.',
  );
  String get watchAd => _pick('Watch', 'Regarder', 'Ver');
  String get notNow => _pick('Not now', 'Plus tard', 'Ahora no');

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
  String get finish => _pick('FINISH', 'TERMINER', 'TERMINAR');
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
  String levelsToMedal(int count) => _pick(
    '$count levels to your chapter medal',
    '$count niveaux avant la médaille du chapitre',
    '$count niveles para la medalla del capítulo',
  );

  /// Le résumé d'un chapitre dans la liste des niveaux.
  String chapterSummary(int mastered, int cleared) => _pick(
    '$mastered mastered · '
        '${cleared == 10 ? 'medal collected' : '${10 - cleared} to chapter medal'}',
    '$mastered maîtrisé${mastered > 1 ? 's' : ''} · '
        '${cleared == 10 ? 'médaille obtenue' : '${10 - cleared} avant la médaille'}',
    '$mastered dominado${mastered > 1 ? 's' : ''} · '
        '${cleared == 10 ? 'medalla obtenida' : '${10 - cleared} para la medalla'}',
  );

  /// Ce qu'il reste sur la grille quand les coups sont épuisés.
  String blocksLeft(int count) => _pick(
    count > 1 ? '$count blocks left' : 'one block left',
    count > 1 ? '$count blocs restants' : 'un bloc restant',
    count > 1 ? 'quedan $count bloques' : 'queda un bloque',
  );

  String get medalCollectedShort =>
      _pick('Medal collected', 'Médaille obtenue', 'Medalla obtenida');

  String get outOfMoves =>
      _pick('OUT OF MOVES', 'PLUS DE COUPS', 'SIN MOVIMIENTOS');
  String get retry => _pick('RETRY', 'RÉESSAYER', 'REINTENTAR');
  String extraMoves(int count) =>
      _pick('+$count MOVES', '+$count COUPS', '+$count MOVIMIENTOS');

  // ── Réglages ───────────────────────────────────────────────────────────
  String get settings => _pick('SETTINGS', 'RÉGLAGES', 'AJUSTES');
  String get haptics => _pick('HAPTICS', 'VIBRATIONS', 'VIBRACIÓN');
  String get backgroundLabel =>
      _pick('BACKGROUND', 'COULEUR DE FOND', 'COLOR DE FONDO');
  String get languageLabel => _pick('LANGUAGE', 'LANGUE', 'IDIOMA');
  String get resetProgress =>
      _pick('RESET PROGRESS', 'EFFACER LA PROGRESSION', 'BORRAR EL PROGRESO');
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
}

/// Porte la langue choisie jusqu'aux écrans.
///
/// Changer de langue reconstruit tout l'arbre : c'est un réglage qu'on touche
/// une fois, pas une animation, et cela évite d'avoir à propager l'objet à la
/// main dans chaque écran.
class LanguageScope extends InheritedWidget {
  const LanguageScope({super.key, required this.strings, required super.child});

  final Strings strings;

  @override
  bool updateShouldNotify(LanguageScope old) =>
      old.strings.language != strings.language;
}
