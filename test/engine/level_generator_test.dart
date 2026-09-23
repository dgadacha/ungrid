import 'package:flutter_test/flutter_test.dart';
import 'package:ungrid/game/engine/difficulty_config.dart';
import 'package:ungrid/game/engine/level_generator.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/levels/level_pattern.dart';

void main() {
  const generator = LevelGenerator();
  const solver = LevelSolver();

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

  group('tuiles d\'arrêt', () {
    test('elles restent rares : le board doit rester lisible', () {
      for (var id = 20; id <= 150; id += 7) {
        final level = generator.generate(levelId: id).level;
        expect(level.stopTiles.length,
            lessThanOrEqualTo(DifficultyCurve.configFor(id).stopTileBudget),
            reason: 'niveau $id : plus de tuiles que le budget');
        expect(level.stopTiles.length, lessThanOrEqualTo(level.columns - 2),
            reason: 'niveau $id : grille encombrée');
      }
    });

    test('deux tuiles ne partagent jamais une case', () {
      for (var id = 20; id <= 200; id += 11) {
        final level = generator.generate(levelId: id).level;
        final cells = <(int, int)>{};
        for (final tile in level.stopTiles) {
          expect(cells.add((tile.x, tile.y)), isTrue, reason: 'niveau $id');
          expect(tile.isInside(level.columns, level.rows), isTrue);
        }
      }
    });

    test('une tuile peut porter un bloc au départ', () {
      // Rien ne l'interdit : un bloc qui démarre sur une tuile n'est pas
      // retenu par elle. Le test garde la règle explicite.
      final level = generator.generate(levelId: 42).level;
      expect(level.isStructurallyValid, isTrue);
    });
  });

  group('limite de coups', () {
    test('la limite est la solution optimale, partout', () {
      for (var id = 1; id <= 150; id += 7) {
        final level = generator.generate(levelId: id).level;
        expect(level.moveLimit, level.optimalMoves,
            reason: 'niveau $id : le joueur doit jouer juste');
      }
    });

    test('chaque niveau connaît son vrai optimal', () {
      // Depuis le glissement, ce n'est plus le nombre de blocs : sans le
      // solveur, les niveaux qui demandent un repositionnement seraient
      // impossibles à finir.
      for (var id = 1; id <= 60; id += 7) {
        final level = generator.generate(levelId: id).level;
        expect(level.optimalMoves, solver.solve(level).minimumMoves,
            reason: 'niveau $id');
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

    test('les premiers niveaux restent plus doux que les suivants', () {
      // On ne compare pas à un seuil : depuis les tuiles d'arrêt, le rapport
      // coups / blocs ne dit plus à lui seul ce qu'un niveau demande — une
      // tuile l'augmente avec un tap forcé, qui ne décide de rien. Les seuils
      // définitifs viendront du benchmark ; ce qui doit tenir maintenant,
      // c'est la pente.
      double averageDifficulty(int from, int to) {
        var sum = 0.0;
        var count = 0;
        for (var id = from; id <= to; id++) {
          sum += generator.generate(levelId: id).analysis.difficultyScore();
          count++;
        }
        return sum / count;
      }

      final start = averageDifficulty(1, 12);
      final later = averageDifficulty(60, 71);
      expect(start, lessThan(later),
          reason: 'le début doit rester plus doux que la suite '
              '(${start.toStringAsFixed(1)} contre ${later.toStringAsFixed(1)})');
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
