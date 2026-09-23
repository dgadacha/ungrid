import 'package:flutter/foundation.dart';

import '../campaign/campaign_catalog.dart';
import '../engine/level_generator.dart';
import '../models/level.dart';

/// Fournit les niveaux au jeu.
///
/// La campagne officielle est la source : le catalogue donne une seed, le
/// niveau se reconstruit à l'identique chez tout le monde. Level 284 désigne
/// le même puzzle pour tous, aujourd'hui comme après une mise à jour — sans
/// quoi ni les solutions partagées ni les comparaisons entre joueurs n'ont de
/// sens.
///
/// Le générateur reste là comme filet : si le catalogue manque ou s'arrête
/// avant, le jeu continue avec des niveaux fabriqués à la volée.
class LevelRepository {
  LevelRepository({
    this.catalog,
    this.generator = const LevelGenerator(),
    this.useIsolate = true,
  });

  /// Campagne publiée. `null` tant qu'elle n'est pas chargée.
  CampaignCatalog? catalog;

  final LevelGenerator generator;

  /// Désactivé dans les tests, où il n'y a pas de binding Flutter.
  final bool useIsolate;

  final Map<int, Level> _cache = {};
  final Map<int, Future<Level>> _pending = {};

  /// Niveaux conservés autour de celui en cours.
  static const int _prefetchCount = 5;

  /// Coups accordés au joueur : exactement la solution optimale.
  ///
  /// Aucune marge, à aucun niveau. Le but n'est pas de vider la grille mais
  /// de trouver la bonne séquence ; accorder un coup de trop, même pour
  /// apprendre, enseignerait justement le contraire. Une erreur se reprend
  /// avec l'annulation, qui rend le coup.
  int moveLimitFor(int levelId, Level level) =>
      catalog?.definitionFor(levelId)?.optimalMoves ?? level.optimalMoves;

  Future<Level> levelFor(int levelId) async {
    final cached = _cache[levelId];
    if (cached != null) return cached;

    final official = catalog?.levelFor(levelId);
    if (official != null) return _cache[levelId] = official;

    final pending = _pending[levelId];
    if (pending != null) return pending;

    final future = _generate(levelId);
    _pending[levelId] = future;
    final level = await future;
    _pending.remove(levelId);
    _cache[levelId] = level;
    return level;
  }

  /// Version bloquante, réservée aux tests et à l'écran d'analyse.
  Level levelForSync(int levelId) => _cache[levelId] ??=
      catalog?.levelFor(levelId) ??
          generator.generate(levelId: levelId).level;

  Future<Level> _generate(int levelId) {
    if (!useIsolate) {
      return Future.value(generator.generate(levelId: levelId).level);
    }
    return compute(_generateInIsolate, levelId);
  }

  /// Prépare les niveaux suivants pendant que le joueur joue celui-ci.
  void prefetchAround(int levelId) {
    for (var id = levelId + 1; id <= levelId + _prefetchCount; id++) {
      if (_cache.containsKey(id) || _pending.containsKey(id)) continue;
      levelFor(id);
    }
    _cache.removeWhere(
      (id, _) => id < levelId - 1 || id > levelId + _prefetchCount,
    );
  }

  void clearCache() {
    _cache.clear();
    _pending.clear();
  }
}

/// Point d'entrée de l'isolate : doit rester une fonction de premier niveau.
Level _generateInIsolate(int levelId) =>
    const LevelGenerator().generate(levelId: levelId).level;
