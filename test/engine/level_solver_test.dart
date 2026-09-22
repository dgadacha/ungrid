import 'package:flutter_test/flutter_test.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/levels/level_pattern.dart';
import 'package:ungrid/game/models/level.dart';

Level parse(List<String> rows) => LevelPattern.parse(rows, id: 1);

void main() {
  const solver = LevelSolver();

  test('une grille vide est résolue', () {
    final empty =
        Level(id: 1, rows: 4, columns: 4, blocks: const [], optimalMoves: 0);
    final result = solver.solve(empty);
    expect(result.solvable, isTrue);
    expect(result.minimumMoves, 0);
  });

  test('un bloc seul sort en un coup', () {
    final result = solver.solve(parse([
      '....',
      '.>..',
      '....',
      '....',
    ]));
    expect(result.solvable, isTrue);
    expect(result.minimumMoves, 1);
    expect(result.exampleSolution, ['b0']);
  });

  test('chaque bloc compte au moins un coup', () {
    final level = parse([
      '....',
      '>..^',
      '....',
      '....',
    ]);
    final result = solver.solve(level);
    expect(result.minimumMoves, greaterThanOrEqualTo(level.blocks.length));
  });

  test('deux blocs face à face bloquent le niveau', () {
    // Chacun glisse vers l'autre, puis plus rien ne bouge : c'est une impasse
    // dont on ne revient pas.
    final result = solver.solve(parse([
      '....',
      '>..<',
      '....',
      '....',
    ]));
    expect(result.solvable, isFalse);
    expect(result.deadEndCount, greaterThan(0));
  });

  test('un repositionnement peut être nécessaire', () {
    // Aucun bloc ne peut sortir : il faut d'abord pousser le bloc du haut à
    // gauche pour dégager la colonne, ce qui coûte un coup de plus que le
    // nombre de blocs.
    final level = parse([
      '>.v.',
      '....',
      '....',
      '^.<.',
    ]);
    final result = solver.solve(level);
    expect(result.solvable, isTrue);
    expect(result.minimumMoves, greaterThan(level.blocks.length),
        reason: 'un bloc doit être joué deux fois');
  });

  test('la solution proposée vide réellement la grille', () {
    final level = parse([
      '..<v.',
      '>>^.v',
      '...v.',
      '.^..>',
      '.v^<.',
    ]);
    final result = solver.solve(level);
    expect(result.solvable, isTrue);
    expect(result.exampleSolution, hasLength(result.minimumMoves));
  });

  group('murs', () {
    test('un bloc s\'arrête au mur au lieu de sortir', () {
      // Le bloc glisse jusqu'au mur, puis ne peut plus rien faire.
      final result = solver.solve(parse([
        '....',
        '>..#',
        '....',
        '....',
      ]));
      expect(result.solvable, isFalse);
    });

    test('un mur hors trajectoire ne gêne rien', () {
      final result = solver.solve(parse([
        '.#..',
        '>...',
        '....',
        '....',
      ]));
      expect(result.solvable, isTrue);
      expect(result.minimumMoves, 1);
    });

    test('les murs restent en place', () {
      final level = parse([
        '.#..',
        '..>.',
        '....',
        '..#.',
      ]);
      expect(level.walls, hasLength(2));
      expect(solver.solve(level).solvable, isTrue);
    });
  });

  group('indice', () {
    test('il désigne un coup qui mène à la victoire', () {
      final level = parse([
        '....',
        '>..^',
        '....',
        '....',
      ]);
      final move = solver.nextBestMove(level, const []);
      expect(move, isNotNull);
      expect(level.blocks.map((b) => b.id), contains(move));
    });

    test('il n\'en propose aucun sur une position perdue', () {
      final level = parse([
        '....',
        '><..',
        '....',
        '....',
      ]);
      expect(solver.nextBestMove(level, const []), isNull);
    });
  });
}
