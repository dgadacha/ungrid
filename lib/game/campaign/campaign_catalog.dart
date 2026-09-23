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
/// Le catalogue ne contient pas les boards : il contient des seeds. Le niveau
/// se reconstruit à l'ouverture, et l'empreinte vérifie qu'on obtient bien
/// celui qui a été publié. Un niveau qui changerait en cours de route rendrait
/// fausses toutes les solutions déjà partagées.
class CampaignCatalog {
  CampaignCatalog(this.campaign, {this.generator = const SlideGenerator()});

  static const String assetPath = 'assets/levels/campaign_v2.json';

  final Campaign campaign;
  final PuzzleGenerator generator;

  final Map<int, Level> _cache = {};

  static Future<CampaignCatalog> load() async {
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return CampaignCatalog(Campaign.fromJson(json));
  }

  int get levelCount => campaign.levelCount;

  CampaignLevel? definitionFor(int levelId) => campaign[levelId];

  /// Reconstruit le niveau [levelId].
  ///
  /// Les premiers sont écrits à la main ; les suivants sortent de leur seed.
  /// En debug, l'empreinte est comparée à celle du catalogue : une régression
  /// du générateur se voit immédiatement, plutôt qu'à la première réclamation
  /// d'un joueur.
  Level? levelFor(int levelId) {
    final cached = _cache[levelId];
    if (cached != null) return cached;

    final definition = campaign[levelId];
    if (definition == null || definition.status != LevelStatus.active) {
      return null;
    }

    final level = generator
        .fromSeed(definition.seed, levelId: levelId)
        ?.copyWith(optimalMoves: definition.optimalMoves);
    if (level == null) return null;

    assert(() {
      final actual = LevelFingerprint.of(level);
      if (actual != definition.fingerprint) {
        throw StateError(
          'Niveau $levelId : le board ne correspond plus au catalogue.\n'
          'attendu ${definition.fingerprint}, obtenu $actual.\n'
          'Le générateur a changé : publiez une nouvelle version plutôt que '
          'de modifier la v$currentGeneratorVersion.',
        );
      }
      return true;
    }());

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
