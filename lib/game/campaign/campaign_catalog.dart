import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../engine/generator_version.dart';
import '../engine/level_fingerprint.dart';
import '../engine/slide_generator.dart';
import '../models/level.dart';
import 'campaign_level.dart';

/// La campagne officielle, telle que tous les joueurs la reçoivent.
///
/// La v3 embarque les grilles validées hors ligne pour charger sans solveur.
/// Les anciens catalogues restent reconstruits depuis leurs seeds v2.
/// L'empreinte est vérifiée dans toutes les configurations de compilation.
class CampaignCatalog {
  CampaignCatalog(this.campaign, {this.generator = const SlideGenerator()});

  static const String assetPath = 'assets/levels/campaign_v3.json';

  final Campaign campaign;
  final PuzzleGenerator generator;

  final Map<int, Level> _cache = {};

  static Future<CampaignCatalog> load({String path = assetPath}) async =>
      parse(await rootBundle.loadString(path));

  /// Construit le catalogue depuis le JSON déjà lu.
  ///
  /// Les tests de widget passent par là : leur horloge est simulée, si bien
  /// qu'une lecture de fichier attendue directement ne se termine jamais. Ils
  /// lisent donc le catalogue eux-mêmes, sous `runAsync`, et le donnent ici.
  static CampaignCatalog parse(String raw) =>
      CampaignCatalog(Campaign.fromJson(jsonDecode(raw) as Map<String, dynamic>));

  int get levelCount => campaign.levelCount;

  CampaignLevel? definitionFor(int levelId) => campaign[levelId];

  /// Reconstruit le niveau [levelId].
  ///
  /// Charge la grille publiée, ou reconstruit une ancienne seed v2.
  Level? levelFor(int levelId) {
    final cached = _cache[levelId];
    if (cached != null) return cached;

    final definition = campaign[levelId];
    if (definition == null || definition.status != LevelStatus.active) {
      return null;
    }

    if (definition.board == null &&
        definition.generatorVersion != currentGeneratorVersion) {
      throw StateError(
        'Version de génération non prise en charge : ${definition.generatorVersion}',
      );
    }
    final level =
        (definition.board ??
                generator.fromSeed(definition.seed, levelId: levelId))
            ?.copyWith(
              id: levelId,
              seed: definition.seed,
              optimalMoves: definition.optimalMoves,
              difficulty: definition.difficulty,
            );
    if (level == null) return null;

    if (!level.isStructurallyValid ||
        LevelFingerprint.of(level) != definition.fingerprint) {
      throw StateError(
        'Niveau $levelId : grille publiée invalide ou empreinte différente.',
      );
    }

    return _cache[levelId] = level;
  }

  void clearCache() => _cache.clear();
}

/// Catalogue de secours, quand le fichier officiel manque.
///
/// Sert au développement et aux tests : le jeu reste jouable, mais les niveaux
/// ne sont plus ceux de la campagne publiée.
@visibleForTesting
Campaign emptyCampaign() => const Campaign(
  catalogVersion: 0,
  generatorVersion: currentGeneratorVersion,
  levels: [],
);
