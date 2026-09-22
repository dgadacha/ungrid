import 'package:flutter_test/flutter_test.dart';
import 'package:ungrid/game/engine/game_engine.dart';
import 'package:ungrid/game/levels/level_pattern.dart';
import 'package:ungrid/game/models/grid_position.dart';
import 'package:ungrid/game/models/level.dart';
import 'package:ungrid/game/models/move_result.dart';

Level parse(List<String> rows) => LevelPattern.parse(rows, id: 1);

GameEngine engineFor(List<String> rows) => GameEngine(parse(rows));

void main() {
  group('glissement', () {
    test('un bloc sans obstacle quitte la grille', () {
      final engine = engineFor([
        '....',
        '.>..',
        '....',
        '....',
      ]);
      final result = engine.tap('b0');
      expect(result.outcome, MoveOutcome.exited);
      expect(engine.remainingCount, 0);
    });

    test('un bloc s\'arrête juste avant un autre', () {
      // b0 '>' en (0,1), b1 '<' en (3,1) : deux cases libres entre eux.
      final engine = engineFor([
        '....',
        '>..<',
        '....',
        '....',
      ]);
      final result = engine.tap('b0');
      expect(result.outcome, MoveOutcome.slid);
      expect(result.to, const GridPosition(2, 1));
      expect(engine.blockAt(2, 1)?.id, 'b0');
      expect(engine.blockAt(0, 1), isNull);
      expect(engine.remainingCount, 2, reason: 'il reste dans la grille');
    });

    test('un bloc s\'arrête juste avant un mur', () {
      final engine = engineFor([
        '....',
        '>..#',
        '....',
        '....',
      ]);
      final result = engine.tap('b0');
      expect(result.outcome, MoveOutcome.slid);
      expect(result.to, const GridPosition(2, 1));
      expect(result.blockedByWall, isTrue);
    });

    test('un obstacle collé au bloc le laisse sur place', () {
      final engine = engineFor([
        '....',
        '><..',
        '....',
        '....',
      ]);
      final result = engine.tap('b0');
      expect(result.outcome, MoveOutcome.blocked);
      expect(engine.blockAt(0, 1)?.id, 'b0');
    });

    test('un mur collé au bloc le laisse sur place', () {
      final engine = engineFor([
        '....',
        '>#..',
        '....',
        '....',
      ]);
      final result = engine.tap('b0');
      expect(result.outcome, MoveOutcome.blocked);
      expect(result.blockedByWall, isTrue);
    });

    test('la direction ne change jamais', () {
      final engine = engineFor([
        '....',
        '>..<',
        '....',
        '....',
      ]);
      final before = engine.blockById('b0')!.direction;
      engine.tap('b0');
      expect(engine.blockById('b0')!.direction, before);
    });

    test('un déplacement libère la route d\'un autre bloc', () {
      // b1 '^' bloque b0 '>' ; en glissant vers le haut, b1 dégage la ligne.
      final engine = engineFor([
        '....',
        '>.^.',
        '....',
        '....',
      ]);
      expect(engine.canExit('b0'), isFalse);
      engine.tap('b1');
      expect(engine.remainingCount, 1);
      expect(engine.canExit('b0'), isTrue);
    });

    test('un déplacement peut aussi barrer la route', () {
      // b0 descend, s'arrête avant le mur, et se retrouve en travers de b1.
      final engine = engineFor([
        '.v..',
        '....',
        '>...',
        '.#..',
      ]);
      expect(engine.canExit('b1'), isTrue);
      engine.tap('b0');
      expect(engine.blockAt(1, 2)?.id, 'b0');
      expect(engine.canExit('b1'), isFalse,
          reason: 'un bloc déplacé devient un obstacle pour les autres');
    });
  });

  group('les quatre directions', () {
    for (final entry in {
      'up': ['....', '....', '..^.', '....'],
      'down': ['....', '..v.', '....', '....'],
      'left': ['....', '..<.', '....', '....'],
      'right': ['....', '..>.', '....', '....'],
    }.entries) {
      test('${entry.key} : sortie sans obstacle', () {
        final engine = engineFor(entry.value);
        expect(engine.tap('b0').outcome, MoveOutcome.exited);
      });
    }
  });

  group('murs', () {
    test('un mur n\'est pas un bloc', () {
      final engine = engineFor([
        '.#..',
        '..>.',
        '....',
        '....',
      ]);
      expect(engine.blockAt(1, 0), isNull);
      expect(engine.isWall(1, 0), isTrue);
      expect(engine.remainingCount, 1);
    });

    test('la grille se vide sans que les murs partent', () {
      final engine = engineFor([
        '.#..',
        '..>.',
        '....',
        '..#.',
      ]);
      engine.tap('b0');
      expect(engine.isCompleted, isTrue);
      expect(engine.isWall(1, 0), isTrue);
      expect(engine.isWall(2, 3), isTrue);
    });
  });

  group('annulation', () {
    test('elle ramène un bloc sorti à sa place', () {
      final engine = engineFor([
        '....',
        '.>..',
        '....',
        '....',
      ]);
      engine.tap('b0');
      expect(engine.remainingCount, 0);

      final record = engine.undo();
      expect(record?.exited, isTrue);
      expect(engine.remainingCount, 1);
      expect(engine.blockAt(1, 1)?.id, 'b0');
    });

    test('elle ramène un bloc glissé à sa case de départ', () {
      final engine = engineFor([
        '....',
        '>..<',
        '....',
        '....',
      ]);
      engine.tap('b0');
      expect(engine.blockAt(2, 1)?.id, 'b0');

      engine.undo();
      expect(engine.blockAt(0, 1)?.id, 'b0');
      expect(engine.blockAt(2, 1), isNull);
    });

    test('un refus ne laisse rien à annuler', () {
      final engine = engineFor([
        '....',
        '><..',
        '....',
        '....',
      ]);
      engine.tap('b0');
      expect(engine.canUndo, isFalse);
    });

    test('elle se remonte coup par coup', () {
      final engine = engineFor([
        '....',
        '>..#',
        '....',
        '..^.',
      ]);
      engine.tap('b0'); // glisse jusqu'en (2,1)
      engine.tap('b1'); // monte et s'arrête sous... rien : il sort
      expect(engine.history, hasLength(2));

      engine.undo();
      engine.undo();
      expect(engine.canUndo, isFalse);
      expect(engine.blockAt(0, 1)?.id, 'b0');
      expect(engine.blockAt(2, 3)?.id, 'b1');
    });
  });

  test('reset revient à l\'état initial', () {
    final engine = engineFor([
      '....',
      '>..<',
      '....',
      '....',
    ]);
    engine.tap('b0');
    engine.reset();
    expect(engine.blockAt(0, 1)?.id, 'b0');
    expect(engine.remainingCount, 2);
    expect(engine.canUndo, isFalse);
  });

  test('restore rejoue une suite de coups', () {
    final engine = engineFor([
      '....',
      '>..<',
      '....',
      '....',
    ]);
    engine.tap('b0');
    final history = engine.history;
    engine.reset();
    engine.restore(history);
    expect(engine.blockAt(2, 1)?.id, 'b0');
  });

  test('un tap sur un bloc absent est ignoré', () {
    final engine = engineFor([
      '....',
      '.>..',
      '....',
      '....',
    ]);
    expect(engine.tap('zzz').outcome, MoveOutcome.ignored);
  });
}
