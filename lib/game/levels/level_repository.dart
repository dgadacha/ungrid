import 'package:flutter/foundation.dart';

import '../engine/level_generator.dart';
import '../models/level.dart';
import 'manual_levels.dart';

/// Fournit les niveaux au jeu, d'où qu'ils viennent.
///
/// Les vingt premiers sont écrits à la main ; les suivants sont fabriqués à la
/// demande. La génération étant déterministe, rien n'est stocké : le numéro du
/// niveau suffit à le reconstruire à l'identique.
///
/// Elle tourne dans un isolate pour ne jamais retenir une frame, et les
/// niveaux à venir sont préparés pendant que le joueur réfléchit au sien.
class LevelRepository {
  LevelRepository({
    this.generator = const LevelGenerator(),
    this.useIsolate = true,
  });

  final LevelGenerator generator;

  /// Désactivé dans les tests, où il n'y a pas de binding Flutter.
  final bool useIsolate;

  final Map<int, Level> _cache = {};
  final Map<int, Future<Level>> _pending = {};

  /// Niveaux conservés autour de celui en cours.
  static const int _prefetchCount = 5;

  bool isManual(int levelId) => ManualLevels.contains(levelId);

  Future<Level> levelFor(int levelId) async {
    final cached = _cache[levelId];
    if (cached != null) return cached;

    if (ManualLevels.contains(levelId)) {
      final level = ManualLevels.byId(levelId);
      _cache[levelId] = level;
      return level;
    }

    final pending = _pending[levelId];
    if (pending != null) return pending;

    final future = _generate(levelId);
    _pending[levelId] = future;
    final level = await future;
    _pending.remove(levelId);
    _cache[levelId] = level;
    return level;
  }

  /// Version bloquante, réservée aux tests et à l'écran de debug.
  Level levelForSync(int levelId) => _cache[levelId] ??=
      ManualLevels.contains(levelId)
          ? ManualLevels.byId(levelId)
          : generator.generate(levelId: levelId).level;

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
