import 'package:shared_preferences/shared_preferences.dart';

import '../game/engine/generator_version.dart';

/// Ce qu'on retient d'un niveau terminé.
///
/// Les deux records sont indépendants : le meilleur temps et le plus petit
/// nombre de coups ne viennent pas forcément de la même partie. On peut
/// chercher l'un puis l'autre, et c'est ce qui donne envie de rejouer un
/// niveau déjà réussi.
class LevelProgress {
  const LevelProgress({
    required this.levelId,
    required this.completed,
    this.bestMovesUsed,
    this.bestTime,
  });

  final int levelId;
  final bool completed;
  final int? bestMovesUsed;
  final Duration? bestTime;
}

/// Sauvegarde locale de la progression.
///
/// Seul point de contact avec le stockage : l'interface ne touche jamais
/// `SharedPreferences` directement, ce qui permet de changer de support sans
/// rien réécrire ailleurs.
class ProgressService {
  ProgressService._(this._prefs);

  static const String _kHighestUnlocked = 'highest_unlocked_level';
  static const String _kHaptics = 'haptics_enabled';
  static const String _kGeneratorVersion = 'progress_generator_version';
  static String _kCompleted(int id) => 'level_${id}_completed';
  static String _kMoves(int id) => 'level_${id}_best_moves';
  static String _kTime(int id) => 'level_${id}_best_time';

  final SharedPreferences _prefs;

  /// La progression a été effacée parce que les niveaux ont changé.
  bool _resetForNewLevels = false;

  /// À dire au joueur une fois, au lancement : ses records ne portaient plus
  /// sur les mêmes puzzles.
  bool get wasResetForNewLevels => _resetForNewLevels;

  static Future<ProgressService> load() async {
    final service = ProgressService._(await SharedPreferences.getInstance());
    await service._reconcileGeneratorVersion();
    return service;
  }

  /// Efface la progression quand les boards ne sont plus les mêmes.
  ///
  /// Un niveau n'est qu'un numéro : le puzzle qu'il désigne vient du
  /// générateur. Quand celui-ci change, le niveau 7 n'est plus le même
  /// board, et le record de coups qu'on y avait posé ne veut plus rien dire —
  /// il porterait sur un puzzle que personne ne peut plus rejouer.
  ///
  /// Une progression sans version inscrite date d'avant cette mécanique :
  /// elle vient forcément d'un générateur antérieur, donc elle s'efface aussi.
  Future<void> _reconcileGeneratorVersion() async {
    final stored = _prefs.getInt(_kGeneratorVersion);
    if (stored == currentGeneratorVersion) return;

    final hasProgress = _prefs.getInt(_kHighestUnlocked) != null ||
        _prefs.getBool(_kCompleted(1)) == true;
    if (stored != null || hasProgress) {
      await resetProgress();
      _resetForNewLevels = hasProgress;
    }
    await _prefs.setInt(_kGeneratorVersion, currentGeneratorVersion);
  }

  /// Le joueur a vu le message : on ne le lui répète pas.
  void acknowledgeReset() => _resetForNewLevels = false;

  int get highestUnlockedLevel => _prefs.getInt(_kHighestUnlocked) ?? 1;

  bool get hapticsEnabled => _prefs.getBool(_kHaptics) ?? true;

  Future<void> setHapticsEnabled(bool value) =>
      _prefs.setBool(_kHaptics, value);

  bool isUnlocked(int levelId) => levelId <= highestUnlockedLevel;

  bool isCompleted(int levelId) => _prefs.getBool(_kCompleted(levelId)) ?? false;

  LevelProgress? progressFor(int levelId) {
    if (!isCompleted(levelId)) return null;
    final time = _prefs.getInt(_kTime(levelId));
    return LevelProgress(
      levelId: levelId,
      completed: true,
      bestMovesUsed: _prefs.getInt(_kMoves(levelId)),
      bestTime: time == null ? null : Duration(milliseconds: time),
    );
  }

  /// Enregistre une victoire et retourne les records battus au passage.
  Future<RecordsBeaten> recordCompletion({
    required int levelId,
    required int movesUsed,
    required Duration time,
  }) async {
    final previous = progressFor(levelId);

    final beatsMoves =
        previous?.bestMovesUsed == null || movesUsed < previous!.bestMovesUsed!;
    final beatsTime = previous?.bestTime == null || time < previous!.bestTime!;

    await _prefs.setBool(_kCompleted(levelId), true);
    if (beatsMoves) await _prefs.setInt(_kMoves(levelId), movesUsed);
    if (beatsTime) await _prefs.setInt(_kTime(levelId), time.inMilliseconds);
    if (levelId + 1 > highestUnlockedLevel) {
      await _prefs.setInt(_kHighestUnlocked, levelId + 1);
    }

    // Un premier passage n'est pas un record : il n'y avait rien à battre.
    final hadPrevious = previous != null;
    return RecordsBeaten(
      time: hadPrevious && beatsTime,
      moves: hadPrevious && beatsMoves,
    );
  }

  /// Nombre de niveaux terminés, pour l'écran d'accueil.
  int completedCount() {
    var total = 0;
    for (var id = 1; id < highestUnlockedLevel; id++) {
      if (isCompleted(id)) total++;
    }
    return total;
  }

  Future<void> resetProgress() async {
    final highest = highestUnlockedLevel;
    for (var id = 1; id <= highest; id++) {
      await _prefs.remove(_kCompleted(id));
      await _prefs.remove(_kMoves(id));
      await _prefs.remove(_kTime(id));
    }
    await _prefs.remove(_kHighestUnlocked);
  }
}

/// Records battus à l'issue d'une partie.
class RecordsBeaten {
  const RecordsBeaten({required this.time, required this.moves});

  const RecordsBeaten.none()
      : time = false,
        moves = false;

  final bool time;
  final bool moves;

  bool get any => time || moves;
  bool get both => time && moves;
}
