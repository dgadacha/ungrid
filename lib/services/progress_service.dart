import 'package:shared_preferences/shared_preferences.dart';

import '../app/strings.dart';
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
    this.mastered = false,
  });

  final int levelId;
  final bool completed;
  final bool mastered;
  final int? bestMovesUsed;
  final Duration? bestTime;
}

/// Sauvegarde locale de la progression.
///
/// Seul point de contact avec le stockage : l'interface ne touche jamais
/// `SharedPreferences` directement, ce qui permet de changer de support sans
/// rien réécrire ailleurs.
class ProgressService {
  ProgressService._(this._prefs, this._prefix);

  final String _prefix;

  String get _kHighestUnlocked => '${_prefix}highest_unlocked_level';
  static const String _kHaptics = 'haptics_enabled';
  static const String _kLanguage = 'language';
  String get _kGeneratorVersion => '${_prefix}progress_generator_version';
  String _kCompleted(int id) => '${_prefix}level_${id}_completed';
  String _kMoves(int id) => '${_prefix}level_${id}_best_moves';
  String _kTime(int id) => '${_prefix}level_${id}_best_time';
  String _kMastered(int id) => '${_prefix}level_${id}_mastered';

  final SharedPreferences _prefs;

  /// La progression a été effacée parce que les niveaux ont changé.
  bool _resetForNewLevels = false;

  bool startedNewCampaign = false;

  /// À dire au joueur une fois, au lancement : ses records ne portaient plus
  /// sur les mêmes puzzles.
  bool get wasResetForNewLevels => _resetForNewLevels;

  /// Chaque campagne garde ses records ; null désigne les niveaux historiques.
  static Future<ProgressService> load({String? campaignId}) async {
    final prefs = await SharedPreferences.getInstance();
    final service = ProgressService._(
      prefs,
      campaignId == null ? '' : '${campaignId}_',
    );
    service.startedNewCampaign =
        campaignId != null &&
        prefs.getInt(service._kGeneratorVersion) == null &&
        prefs.getKeys().any(
          (key) =>
              key.endsWith('highest_unlocked_level') &&
              key != service._kHighestUnlocked &&
              prefs.getInt(key) != null,
        );
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

    final hasProgress =
        _prefs.getInt(_kHighestUnlocked) != null ||
        _prefs.getBool(_kCompleted(1)) == true;
    if (stored != null || hasProgress) {
      await resetProgress();
      _resetForNewLevels = hasProgress;
    }
    await _prefs.setInt(_kGeneratorVersion, currentGeneratorVersion);
  }

  /// Le joueur a vu le message : on ne le lui répète pas.
  void acknowledgeReset() {
    _resetForNewLevels = false;
    startedNewCampaign = false;
  }

  int get highestUnlockedLevel => _prefs.getInt(_kHighestUnlocked) ?? 1;

  bool get hapticsEnabled => _prefs.getBool(_kHaptics) ?? true;

  Future<void> setHapticsEnabled(bool value) =>
      _prefs.setBool(_kHaptics, value);

  /// Langue de l'interface. Anglais tant que rien n'a été choisi.
  AppLanguage get language =>
      AppLanguage.fromCode(_prefs.getString(_kLanguage));

  Future<void> setLanguage(AppLanguage value) =>
      _prefs.setString(_kLanguage, value.code);

  bool isUnlocked(int levelId) => levelId <= highestUnlockedLevel;

  bool isCompleted(int levelId) =>
      _prefs.getBool(_kCompleted(levelId)) ?? false;

  LevelProgress? progressFor(int levelId) {
    if (!isCompleted(levelId)) return null;
    final time = _prefs.getInt(_kTime(levelId));
    return LevelProgress(
      levelId: levelId,
      completed: true,
      mastered: isMastered(levelId),
      bestMovesUsed: _prefs.getInt(_kMoves(levelId)),
      bestTime: time == null ? null : Duration(milliseconds: time),
    );
  }

  /// Enregistre une victoire et retourne les records battus au passage.
  Future<RecordsBeaten> recordCompletion({
    required int levelId,
    required int movesUsed,
    required Duration time,
    bool mastered = false,
  }) async {
    final previous = progressFor(levelId);

    final beatsMoves =
        previous?.bestMovesUsed == null || movesUsed < previous!.bestMovesUsed!;
    final beatsTime = previous?.bestTime == null || time < previous!.bestTime!;

    await _prefs.setBool(_kCompleted(levelId), true);
    if (mastered) await _prefs.setBool(_kMastered(levelId), true);
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

  bool isMastered(int id) => _prefs.getBool(_kMastered(id)) ?? false;

  int chapterCleared(int chapter) => List.generate(
    10,
    (i) => (chapter - 1) * 10 + i + 1,
  ).where(isCompleted).length;
  int chapterMastered(int chapter) => List.generate(
    10,
    (i) => (chapter - 1) * 10 + i + 1,
  ).where(isMastered).length;
  int get completedChapters => List.generate(
    10,
    (i) => i + 1,
  ).where((c) => chapterCleared(c) == 10).length;
  Future<void> resetProgress() async {
    final highest = highestUnlockedLevel;
    for (var id = 1; id <= highest; id++) {
      await _prefs.remove(_kCompleted(id));
      await _prefs.remove(_kMoves(id));
      await _prefs.remove(_kTime(id));
      await _prefs.remove(_kMastered(id));
    }
    await _prefs.remove(_kHighestUnlocked);
  }
}

/// Records battus à l'issue d'une partie.
class RecordsBeaten {
  const RecordsBeaten({required this.time, required this.moves});

  const RecordsBeaten.none() : time = false, moves = false;

  final bool time;
  final bool moves;

  bool get any => time || moves;
  bool get both => time && moves;
}
