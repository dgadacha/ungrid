import 'package:flutter_test/flutter_test.dart';
import 'package:ungrid/game/engine/difficulty_config.dart';
import 'package:ungrid/game/engine/level_generator.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/levels/level_pattern.dart';
import 'package:ungrid/game/levels/manual_levels.dart';

void main() {
  const generator = LevelGenerator();
  const solver = LevelSolver();

  group('niveaux écrits à la main', () {
    test('les vingt restent jouables', () {
      for (final level in ManualLevels.all()) {
        final result = solver.solve(level);
        final trace = LevelPattern.render(level).join('\n');

        expect(level.isStructurallyValid, isTrue,
            reason: 'niveau ${level.id} mal formé\n$trace');
        expect(result.solvable, isTrue,
            reason: 'niveau ${level.id} insoluble\n$trace');
      }
    });

    test('les premiers niveaux enseignent chacun une règle', () {
      // 1 : le geste. 2 : le glissement. 3 : le refus. 4 : le
      // repositionnement, seul moyen de démarrer.
      expect(ManualLevels.byId(1).blocks, hasLength(1));

      final slide = solver.solve(ManualLevels.byId(2));
      expect(slide.solvable, isTrue);

      final push = ManualLevels.byId(4);
      final pushed = solver.solve(push);
      expect(pushed.solvable, isTrue);
      expect(LevelGenerator.exitableCount(push), 0,
          reason: 'aucun bloc ne doit pouvoir sortir d\'emblée');
      expect(pushed.minimumMoves, greaterThan(push.blocks.length),
          reason: 'il faut jouer un bloc deux fois');
    });

    test('chaque niveau d\'apprentissage a sa phrase', () {
      for (var id = 1; id <= 4; id++) {
        expect(ManualLevels.hintFor(id), isNotNull);
      }
      expect(ManualLevels.hintFor(5), isNull);
    });

    test('la progression va du plus simple au plus fourni', () {
      final first = ManualLevels.byId(1);
      final last = ManualLevels.byId(ManualLevels.count);
      expect(first.blocks, hasLength(1));
      expect(last.blocks.length, greaterThan(first.blocks.length));
    });
  });

  group('génération', () {
    test('un même numéro produit toujours le même board', () {
      for (final id in [21, 42, 137, 427]) {
        final a = generator.generate(levelId: id).level;
        final b = generator.generate(levelId: id).level;
        expect(LevelPattern.render(a), LevelPattern.render(b),
            reason: 'niveau $id non déterministe');
        expect(a.seed, b.seed);
      }
    });

    test('deux niveaux voisins ne partagent pas leur board', () {
      final a = LevelPattern.render(generator.generate(levelId: 60).level);
      final b = LevelPattern.render(generator.generate(levelId: 61).level);
      expect(a, isNot(b));
    });

    test('tout niveau généré est valide et se termine', () {
      for (var id = 21; id <= 90; id++) {
        final generated = generator.generate(levelId: id);
        final level = generated.level;
        final trace = LevelPattern.render(level).join('\n');

        expect(level.isStructurallyValid, isTrue, reason: 'niveau $id\n$trace');
        expect(generated.solveResult.solvable, isTrue,
            reason: 'niveau $id insoluble\n$trace');
        expect(level.blocks.length, greaterThanOrEqualTo(2));
        expect(level.occupancy, lessThan(0.7),
            reason: 'niveau $id : plus rien ne peut glisser');
      }
    });

    test('la solution annoncée est bien la plus courte trouvée', () {
      for (var id = 21; id <= 60; id += 7) {
        final generated = generator.generate(levelId: id);
        expect(generated.level.optimalMoves,
            generated.solveResult.minimumMoves);
        expect(generated.level.optimalMoves,
            greaterThanOrEqualTo(generated.level.blocks.length));
      }
    });

    test('peu de blocs sortent dès le premier coup', () {
      for (var id = 30; id <= 120; id += 5) {
        final generated = generator.generate(levelId: id);
        expect(generated.difficulty.exitableRatio, lessThan(0.6),
            reason: 'niveau $id : le board se vide tout seul');
      }
    });
  });

  group('murs', () {
    test('ils n\'apparaissent qu\'une fois la règle acquise', () {
      for (var id = 1; id <= 15; id++) {
        final level = ManualLevels.contains(id)
            ? ManualLevels.byId(id)
            : generator.generate(levelId: id).level;
        expect(level.walls, isEmpty,
            reason: 'niveau $id : trop tôt pour des obstacles');
      }
    });

    test('ils arrivent ensuite, sans envahir le board', () {
      for (var id = 60; id <= 150; id += 9) {
        final level = generator.generate(levelId: id).level;
        expect(level.walls.length,
            lessThanOrEqualTo(DifficultyCurve.configFor(id).maxWalls));
      }
    });

    test('un mur n\'occupe jamais la case d\'un bloc', () {
      for (var id = 30; id <= 150; id += 13) {
        final level = generator.generate(levelId: id).level;
        final wallCells = {for (final w in level.walls) (w.x, w.y)};
        for (final block in level.blocks) {
          expect(wallCells.contains((block.x, block.y)), isFalse);
        }
      }
    });
  });

  group('limite de coups', () {
    test('la limite est la solution optimale, partout', () {
      for (var id = 1; id <= 150; id += 7) {
        final level = ManualLevels.contains(id)
            ? ManualLevels.byId(id)
            : generator.generate(levelId: id).level;
        expect(level.moveLimit, level.optimalMoves,
            reason: 'niveau $id : le joueur doit jouer juste');
      }
    });

    test('les niveaux écrits connaissent leur vrai optimal', () {
      // Depuis le glissement, ce n'est plus le nombre de blocs : sans le
      // solveur, les niveaux qui demandent un repositionnement seraient
      // impossibles à finir.
      for (final level in ManualLevels.all()) {
        expect(level.optimalMoves, solver.solve(level).minimumMoves,
            reason: 'niveau ${level.id}');
      }
    });
  });

  group('exigences de la campagne', () {
    test('les tranches se suivent sans trou', () {
      var previous = 0;
      for (final band in difficultyBands) {
        expect(band.upToLevel, greaterThan(previous));
        previous = band.upToLevel;
      }
      expect(bandFor(1).name, difficultyBands.first.name);
      expect(bandFor(100000).name, difficultyBands.last.name);
    });

    test('les exigences montent avec les tranches', () {
      for (var i = 1; i < difficultyBands.length; i++) {
        final before = difficultyBands[i - 1];
        final after = difficultyBands[i];
        expect(after.minComplexity, greaterThanOrEqualTo(before.minComplexity));
        expect(after.minDecisionScore,
            greaterThanOrEqualTo(before.minDecisionScore));
        expect(after.maxExitRatio, lessThanOrEqualTo(before.maxExitRatio));
      }
    });

    test('un bloc doit être rejoué dès le milieu de la campagne', () {
      // C'est là que le glissement cesse d'être décoratif : sans
      // repositionnement, chaque bloc sort d'un tap et le niveau se résume à
      // trouver l'ordre.
      var withReposition = 0;
      var checked = 0;
      for (var id = 31; id <= 90; id += 3) {
        final generated = generator.generate(levelId: id);
        checked++;
        if (generated.analysis.multiMoveBlocks > 0) withReposition++;
      }
      expect(withReposition / checked, greaterThan(0.8),
          reason: 'la plupart des niveaux doivent demander un repositionnement');
    });

    test('les niveaux offrent de vrais choix, et donc de vraies erreurs', () {
      for (var id = 31; id <= 120; id += 11) {
        final analysis = generator.generate(levelId: id).analysis;
        expect(analysis.averageChoices, greaterThan(2.0),
            reason: 'niveau $id : un couloir, pas un puzzle');
        expect(analysis.wrongMoveOpportunities, greaterThan(0),
            reason: 'niveau $id : impossible de se tromper');
      }
    });

    test('les premiers niveaux restent doux', () {
      for (var id = 6; id <= 15; id++) {
        final analysis = generator.generate(levelId: id).analysis;
        expect(analysis.moveComplexity, lessThanOrEqualTo(1.3),
            reason: 'niveau $id trop exigeant pour un début');
      }
    });
  });

  group('courbe de difficulté', () {
    test('la difficulté moyenne augmente avec la progression', () {
      double averageScore(int from, int to) {
        var sum = 0.0;
        var count = 0;
        for (var id = from; id <= to; id++) {
          sum += generator.generate(levelId: id).difficulty.score;
          count++;
        }
        return sum / count;
      }

      expect(averageScore(90, 108), greaterThan(averageScore(21, 39)));
    });

    test('la courbe respire : un niveau peut être plus simple que le précédent',
        () {
      var descents = 0;
      for (var id = 30; id <= 90; id++) {
        if (DifficultyCurve.scalarFor(id + 1) < DifficultyCurve.scalarFor(id)) {
          descents++;
        }
      }
      expect(descents, greaterThan(5));
    });

    test('la difficulté reste bornée', () {
      for (final id in [1, 50, 500, 5000]) {
        expect(DifficultyCurve.scalarFor(id), inInclusiveRange(0, 1));
        expect(DifficultyCurve.configFor(id).gridSize, inInclusiveRange(4, 7));
      }
    });
  });
}
