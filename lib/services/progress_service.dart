import 'package:shared_preferences/shared_preferences.dart';

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
  static String _kCompleted(int id) => 'level_${id}_completed';
  static String _kMoves(int id) => 'level_${id}_best_moves';
  static String _kTime(int id) => 'level_${id}_best_time';

  final SharedPreferences _prefs;

  static Future<ProgressService> load() async =>
      ProgressService._(await SharedPreferences.getInstance());

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
