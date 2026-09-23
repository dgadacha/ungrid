import 'package:flutter_test/flutter_test.dart';
import 'package:ungrid/game/engine/game_engine.dart';
import 'package:ungrid/game/engine/generator_version.dart';
import 'package:ungrid/game/engine/level_fingerprint.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/engine/slide_generator.dart';
import 'package:ungrid/game/levels/level_pattern.dart';
import 'package:ungrid/game/models/move_result.dart';

/// `o` marque une tuile d'arrêt, `^ v < >` un bloc et sa direction.
GameEngine engineOf(List<String> rows) =>
    GameEngine(LevelPattern.parse(rows, id: 0));

void main() {
  const solver = LevelSolver(maxExploredStates: 60000);
  const generator = SlideGenerator();

  group('la tuile d\'arrêt', () {
    test('retient le bloc qui entre dessus', () {
      final engine = engineOf(['>.o.', '....']);
      final result = engine.tap('b0');

      expect(result.outcome, MoveOutcome.stopped);
      expect(result.to, engine.blockById('b0')!.position);
      expect(engine.blockAt(2, 0), isNotNull, reason: 'il occupe la tuile');
      expect(engine.remainingCount, 1, reason: 'il n\'est pas sorti');
    });

    test('ne retient pas celui qui en part', () {
      // Le bloc démarre sur la tuile : elle ne doit pas le figer, sans quoi
      // la case deviendrait un piège dont rien ne ressort.
      final engine = GameEngine(LevelPattern.parse(['.>..'], id: 0).copyWith(
        stopTiles: LevelPattern.parse(['.o..'], id: 0).stopTiles,
      ));
      expect(engine.tap('b0').outcome, MoveOutcome.exited);
      expect(engine.isCompleted, isTrue);
    });

    test('deux tuiles sur la route demandent deux taps de plus', () {
      final engine = engineOf(['>.o.o.']);
      expect(engine.tap('b0').outcome, MoveOutcome.stopped);
      expect(engine.blockById('b0')!.x, 2);
      expect(engine.tap('b0').outcome, MoveOutcome.stopped);
      expect(engine.blockById('b0')!.x, 4);
      expect(engine.tap('b0').outcome, MoveOutcome.exited);
    });

    test('un bloc passe avant elle : on s\'arrête devant le bloc', () {
      // La tuile est derrière le bloc bloquant : c'est le bloc qui décide.
      final engine = engineOf(['>.^o.']);
      final result = engine.tap('b0');

      expect(result.outcome, MoveOutcome.slid);
      expect(engine.blockById('b0')!.x, 1, reason: 'juste avant le bloc');
    });

    test('elle passe avant un bloc plus lointain', () {
      final engine = engineOf(['>o.^.']);
      final result = engine.tap('b0');

      expect(result.outcome, MoveOutcome.stopped);
      expect(engine.blockById('b0')!.x, 1);
    });

    test('la route dégagée, le tap suivant fait sortir', () {
      final engine = engineOf(['>o..']);
      expect(engine.tap('b0').outcome, MoveOutcome.stopped);
      expect(engine.tap('b0').outcome, MoveOutcome.exited);
      expect(engine.isCompleted, isTrue);
    });

    test('un arrêt s\'annule comme un glissement', () {
      final engine = engineOf(['>..o.']);
      engine.tap('b0');
      expect(engine.blockById('b0')!.x, 3);

      final undone = engine.undo();
      expect(undone, isNotNull);
      expect(undone!.outcome, MoveOutcome.stopped);
      expect(engine.blockById('b0')!.x, 0, reason: 'revenu à sa case');
      expect(engine.canUndo, isFalse);
    });

    test('un refus ne se produit pas à cause d\'une tuile', () {
      // Seul un bloc collé peut refuser un coup : une tuile déplace toujours
      // d'au moins une case.
      final engine = engineOf(['>^..']);
      expect(engine.tap('b0').outcome, MoveOutcome.blocked);
      expect(engine.canUndo, isFalse, reason: 'rien n\'a bougé');
    });
  });

  group('le solveur', () {
    test('compte les taps répétés qu\'une tuile impose', () {
      final level = LevelPattern.parse(['>.o.'], id: 0);
      final result = solver.solve(level);

      expect(result.solvable, isTrue);
      expect(result.minimumMoves, 2);
      expect(result.exampleSolution, ['b0', 'b0']);
    });

    test('voit le même jeu que le moteur', () {
      // Le moteur et le solveur partagent leur résolveur : rejouer la
      // solution annoncée doit vider la grille, exactement.
      for (var seed = 1; seed <= 120; seed++) {
        final level = generator.fromSeed(seed, levelId: seed);
        if (level == null) continue;
        final result = solver.solve(level);
        if (!result.solvable || !result.exhaustive) continue;

        final engine = GameEngine(level);
        for (final id in result.exampleSolution) {
          final move = engine.tap(id);
          expect(move.outcome, isNot(MoveOutcome.ignored),
              reason: 'seed $seed : le solveur joue un bloc absent');
        }
        expect(engine.isCompleted, isTrue,
            reason: 'seed $seed : la solution ne vide pas la grille\n'
                '${LevelPattern.render(level).join('\n')}');
      }
    });
  });

  group('empreinte et déterminisme', () {
    test('l\'empreinte distingue deux boards aux tuiles différentes', () {
      final a = LevelPattern.parse(['>.o.'], id: 0);
      final b = LevelPattern.parse(['>..o'], id: 0);
      final same = LevelPattern.parse(['>.o.'], id: 7);

      expect(LevelFingerprint.of(a), isNot(LevelFingerprint.of(b)));
      expect(LevelFingerprint.of(a), LevelFingerprint.of(same),
          reason: 'le numéro du niveau n\'entre pas dans l\'empreinte');
    });

    test('une même seed rend toujours le même niveau', () {
      for (final seed in [3, 77, 4242, 99991]) {
        final a = generator.fromSeed(seed, levelId: seed);
        final b = generator.fromSeed(seed, levelId: seed);
        expect(a, isNotNull);
        expect(LevelFingerprint.of(a!), LevelFingerprint.of(b!),
            reason: 'seed $seed non déterministe');
      }
      expect(currentGeneratorVersion, 2,
          reason: 'les règles ont changé : la version aussi');
    });
  });

  group('propriétés de la génération', () {
    test('sur un millier de niveaux, rien ne déborde', () {
      var checked = 0;
      var withTiles = 0;

      for (var seed = 1; seed <= 1000; seed++) {
        final level = generator.fromSeed(seed, levelId: seed);
        if (level == null) continue;
        checked++;

        final trace = LevelPattern.render(level).join('\n');
        expect(level.isStructurallyValid, isTrue, reason: 'seed $seed\n$trace');

        final cells = <int>{};
        for (final tile in level.stopTiles) {
          expect(tile.isInside(level.columns, level.rows), isTrue,
              reason: 'seed $seed : tuile hors grille');
          expect(cells.add(tile.y * level.columns + tile.x), isTrue,
              reason: 'seed $seed : deux tuiles sur la même case');
        }
        if (level.stopTiles.isNotEmpty) withTiles++;

        // Les tuiles ne bougent pas et ne disparaissent pas : après une
        // partie complète, le plateau les porte toujours.
        final engine = GameEngine(level);
        for (final tile in level.stopTiles) {
          expect(engine.hasStopTileAt(tile.x, tile.y), isTrue);
        }
        final result = solver.solve(level);
        if (!result.solvable || !result.exhaustive) continue;

        final directions = {
          for (final block in level.blocks) block.id: block.direction,
        };
        for (final id in result.exampleSolution) {
          engine.tap(id);
          final block = engine.blockById(id);
          if (block != null) {
            expect(block.direction, directions[id],
                reason: 'seed $seed : un bloc a changé de direction');
          }
        }
        expect(engine.isCompleted, isTrue, reason: 'seed $seed\n$trace');
        expect(level.optimalMoves, greaterThanOrEqualTo(level.blocks.length));

        for (final tile in level.stopTiles) {
          expect(engine.hasStopTileAt(tile.x, tile.y), isTrue,
              reason: 'seed $seed : une tuile a disparu en cours de partie');
        }
      }

      expect(checked, greaterThan(800));
      expect(withTiles, greaterThan(checked ~/ 4),
          reason: 'la mécanique doit servir sur une part notable des boards');
    });
  });
}
