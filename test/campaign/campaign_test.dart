@Timeout(Duration(minutes: 10))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ungrid/game/campaign/campaign_catalog.dart';
import 'package:ungrid/game/campaign/campaign_level.dart';
import 'package:ungrid/game/campaign/campaign_profile.dart';
import 'package:ungrid/game/engine/game_engine.dart';
import 'package:ungrid/game/engine/generator_version.dart';
import 'package:ungrid/game/engine/level_fingerprint.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/engine/puzzle_analysis.dart';
import 'package:ungrid/game/engine/slide_generator.dart';
import 'package:ungrid/game/levels/level_repository.dart';

/// La campagne publiée est un engagement : le niveau 284 doit désigner le même
/// puzzle pour tout le monde, aujourd'hui comme après une mise à jour. Ces
/// tests sont là pour qu'une modification du générateur ne le rompe pas en
/// silence.
void main() {
  const solver = LevelSolver();
  const generator = SlideGenerator();

  final file = File('assets/levels/campaign_v2.json');
  final exists = file.existsSync();

  late Campaign campaign;
  late CampaignCatalog catalog;

  setUpAll(() {
    if (!exists) return;
    campaign = Campaign.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
    catalog = CampaignCatalog(campaign);
  });

  group('empreinte', () {
    test('elle ne dépend pas de l\'ordre de construction', () {
      final level = generator.fromSeed(12, levelId: 12)!;
      final shuffled = level.copyWith(
        blocks: level.blocks.reversed.toList(),
        stopTiles: level.stopTiles.reversed.toList(),
      );
      expect(LevelFingerprint.of(shuffled), LevelFingerprint.of(level));
    });

    test('elle change dès que le board change', () {
      final a = LevelFingerprint.of(generator.fromSeed(12, levelId: 12)!);
      final b = LevelFingerprint.of(generator.fromSeed(13, levelId: 13)!);
      expect(a, isNot(b));
    });
  });

  group('génération depuis une seed', () {
    test('une seed donne toujours le même board', () {
      for (final seed in [1, 42, 999983, 123456789]) {
        final first = generator.fromSeed(seed);
        final second = generator.fromSeed(seed);
        if (first == null) continue;
        expect(LevelFingerprint.of(first), LevelFingerprint.of(second!));
      }
    });

    test('deux seeds voisines donnent des boards différents', () {
      final a = generator.fromSeed(1000);
      final b = generator.fromSeed(1001);
      if (a != null && b != null) {
        expect(LevelFingerprint.of(a), isNot(LevelFingerprint.of(b)));
      }
    });
  });

  group('catalogue', () {
    test('le fichier existe', () {
      expect(exists, isTrue,
          reason: 'lancer dart run tool/build_campaign.dart');
    }, skip: exists ? false : 'campagne non construite');

    test('il annonce la version du générateur qui l\'a produit', () {
      expect(campaign.generatorVersion, currentGeneratorVersion);
    }, skip: exists ? false : 'campagne non construite');

    test('les niveaux se suivent sans trou ni doublon', () {
      for (var i = 0; i < campaign.levels.length; i++) {
        expect(campaign.levels[i].levelId, i + 1);
      }
    }, skip: exists ? false : 'campagne non construite');

    test('chaque niveau se reconstruit tel qu\'il a été publié', () {
      // C'est le garde-fou : si le générateur change, les empreintes ne
      // correspondent plus et les solutions déjà partagées deviennent fausses.
      final broken = <int>[];
      for (final definition in campaign.levels) {
        final level = catalog.levelFor(definition.levelId);
        if (level == null ||
            LevelFingerprint.of(level) != definition.fingerprint) {
          broken.add(definition.levelId);
        }
      }
      expect(broken, isEmpty, reason: 'niveaux altérés : $broken');
    }, skip: exists ? false : 'campagne non construite');

    test('tous les niveaux se terminent, dans le compte annoncé', () {
      final broken = <int>[];
      for (final definition in campaign.levels) {
        final level = catalog.levelFor(definition.levelId)!;
        final result = solver.solve(level);
        if (!result.solvable ||
            result.minimumMoves != definition.optimalMoves) {
          broken.add(definition.levelId);
        }
      }
      expect(broken, isEmpty, reason: 'niveaux incohérents : $broken');
    }, skip: exists ? false : 'campagne non construite');

    test('la réserve vaut l\'optimal, à tous les niveaux', () {
      for (final definition in campaign.levels) {
        final level = catalog.levelFor(definition.levelId)!;
        expect(level.moveLimit, definition.optimalMoves,
            reason: 'niveau ${definition.levelId} : aucune marge nulle part');
      }
    }, skip: exists ? false : 'campagne non construite');

    test('aucun board ne revient à portée de mémoire', () {
      final seenAt = <String, int>{};
      final close = <String>[];
      for (final definition in campaign.levels) {
        final previous = seenAt[definition.fingerprint];
        if (previous != null && definition.levelId - previous < 50) {
          close.add('$previous et ${definition.levelId}');
        }
        seenAt[definition.fingerprint] = definition.levelId;
      }
      expect(close, isEmpty, reason: 'boards répétés : $close');
    }, skip: exists ? false : 'campagne non construite');

    test('la campagne durcit du début à la fin', () {
      double average(int from, int to) {
        final slice = campaign.levels
            .where((l) => l.levelId >= from && l.levelId <= to)
            .map((l) => l.optimalMoves)
            .toList();
        return slice.reduce((a, b) => a + b) / slice.length;
      }

      if (campaign.levels.length < 200) return;
      final last = campaign.levels.last.levelId;
      expect(average(last - 99, last), greaterThan(average(30, 129)));
    }, skip: exists ? false : 'campagne non construite');

    test(
      'tous les niveaux respectent le profil validé et leur solution se joue',
      () {
        final raw =
            jsonDecode(
                  File(
                    'assets/levels/campaign_v2_solutions.json',
                  ).readAsStringSync(),
                )
                as Map;
        final solutions = raw['levels'] as List;
        for (final definition in campaign.levels) {
          final level = catalog.levelFor(definition.levelId)!;
          final solved = const LevelSolver(
            maxExploredStates: 60000,
          ).solve(level);
          final analysis = const PuzzleAnalyzer(
            solver: LevelSolver(maxExploredStates: 6000),
          ).analyse(level, solved);
          expect(
            CampaignProfile.forLevel(level.id).accepts(level, analysis),
            isTrue,
            reason: 'niveau ${level.id}',
          );
          final engine = GameEngine(level);
          final sequence = (solutions[level.id - 1] as Map)['solution'] as List;
          expect(sequence.length, level.moveLimit);
          for (final id in sequence.cast<String>()) {
            expect(engine.canMove(id), isTrue);
            engine.tap(id);
          }
          expect(engine.isCompleted, isTrue);
        }
      },
      skip: exists ? false : 'campagne non construite',
    );

    test(
      'aucun niveau hors catalogue ne remplace un défi par une grille facile',
      () async {
        final repository = LevelRepository(
          catalog: catalog,
          lastLevel: campaign.levelCount,
          useIsolate: false,
        );

        // Dans la campagne, chaque niveau vient du catalogue publié.
        for (final definition in campaign.levels) {
          expect(repository.levelForSync(definition.levelId).id,
              definition.levelId);
        }

        // Au-delà, le dépôt refuse. Fabriquer un board à la volée serait pire
        // que de s'arrêter : il n'aurait passé aucun des contrôles qui ont
        // retenu les cent autres, et le joueur croirait continuer la campagne.
        final beyond = campaign.levelCount + 1;
        expect(() => repository.levelForSync(beyond), throwsRangeError);
        await expectLater(repository.levelFor(beyond), throwsRangeError);
      },
      skip: exists ? false : 'campagne non construite',
    );
  });
}
