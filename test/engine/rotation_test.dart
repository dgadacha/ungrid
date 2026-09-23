import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ungrid/game/engine/game_engine.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/engine/level_fingerprint.dart';
import 'package:ungrid/game/engine/rotation_generator.dart';
import 'package:ungrid/game/levels/level_pattern.dart';
import 'package:ungrid/game/models/direction.dart';
import 'package:ungrid/game/models/grid_position.dart';
import 'package:ungrid/game/models/level.dart';

void main() {
  test('rotation à chaque arrivée, sortie, annulation et indice', () {
    final level = LevelPattern.parse([
      '....',
      '>...',
      '....',
      '....',
    ], id: 1).copyWith(rotationTiles: [const GridPosition(1, 1)]);
    final engine = GameEngine(level);
    final id = level.blocks.single.id;
    expect(engine.tap(id).stopped, isTrue);
    expect(engine.blockById(id)!.direction, Direction.down);
    expect(const LevelSolver().nextBestMove(level, engine.history), id);
    expect(engine.tap(id).exited, isTrue);
    engine.undo();
    expect(engine.blockById(id)!.direction, Direction.down);
    engine.undo();
    expect(engine.blockById(id), level.blocks.single);
    expect(const LevelSolver().solve(level).minimumMoves, 2);
  });

  test('bloc déjà sur rotation et refus ne tournent pas', () {
    final level = LevelPattern.parse([
      '....',
      '.>>.',
      '....',
      '....',
    ], id: 1).copyWith(rotationTiles: [const GridPosition(1, 1)]);
    final engine = GameEngine(level);
    final id = engine.blockAt(1, 1)!.id;
    expect(engine.tap(id).blocked, isTrue);
    expect(engine.blockById(id)!.direction, Direction.right);
    engine.tap(engine.blockAt(2, 1)!.id);
    expect(engine.tap(id).exited, isTrue);
  });

  test('cycle fermé terminé par le solveur et retour orientation exacte', () {
    final level = LevelPattern.parse(['....', '.>..', '....', '....'], id: 1)
        .copyWith(
          rotationTiles: const [
            GridPosition(1, 1),
            GridPosition(2, 1),
            GridPosition(2, 2),
            GridPosition(1, 2),
          ],
        );
    final engine = GameEngine(level);
    final id = level.blocks.single.id;
    for (var i = 0; i < 4; i++) {
      engine.tap(id);
    }
    expect(engine.blockById(id), level.blocks.single);
    final solved = const LevelSolver().solve(level);
    expect(solved.solvable, isFalse);
    expect(solved.exhaustive, isTrue);
    expect(solved.exploredStates, 4);
    engine.undo();
    expect(engine.blockById(id)!.direction, Direction.up);
  });

  test('A* retrouve le minimum BFS avec orientations et arrêts fragiles', () {
    for (final direction in Direction.values) {
      final base = LevelPattern.parse(['.v..', '>...', '..<.', '....'], id: 1);
      final level = base.copyWith(
        blocks: [
          base.blocks.first.copyWith(direction: direction),
          ...base.blocks.skip(1),
        ],
        rotationTiles: const [GridPosition(1, 1), GridPosition(2, 1)],
        fragileStopTiles: const [GridPosition(1, 2)],
      );
      final queue = <List<String>>[[]];
      final seen = <String>{};
      int? minimum;
      for (var i = 0; i < queue.length; i++) {
        final engine = GameEngine(level);
        for (final id in queue[i]) {
          engine.tap(id);
        }
        final key =
            '${engine.remainingBlocks.map((b) => '${b.id}:${b.x},${b.y},${b.direction}').join(';')}|${engine.activeStopTiles.join(';')}';
        if (!seen.add(key)) continue;
        if (engine.isCompleted) {
          minimum = queue[i].length;
          break;
        }
        for (final b in engine.movableBlocks()) {
          queue.add([...queue[i], b.id]);
        }
      }
      final solved = const LevelSolver().solve(level);
      expect(solved.exhaustive, isTrue);
      expect(solved.solvable, minimum != null);
      if (minimum != null) expect(solved.minimumMoves, minimum);
    }
  });

  test(
    '10 niveaux générés reproductibles, rotations utiles et budget optimal',
    () {
      final data =
          jsonDecode(File('assets/levels/rotation_v1.json').readAsStringSync())
              as Map;
      expect((data['levels'] as List).length, 10);
      for (final raw in data['levels'] as List) {
        final level = Level.fromJson(raw as Map<String, dynamic>);
        final generated = const RotationGenerator().fromSeed(
          raw['seed'] as int,
          levelId: level.id,
        )!;
        expect(LevelFingerprint.of(level), LevelFingerprint.of(generated));
        expect(
          LevelFingerprint.of(Level.fromJson(level.toJson())),
          LevelFingerprint.of(level),
        );
        expect(level.isStructurallyValid, isTrue);
        final solved = const LevelSolver().solve(level);
        expect(solved.minimumMoves, level.optimalMoves);
        final engine = GameEngine(level);
        final plain = GameEngine(
          level.copyWith(stopTiles: level.rotationTiles, rotationTiles: []),
        );
        final visited = <GridPosition>{};
        for (final id in (raw['solution'] as List).cast<String>()) {
          expect(engine.canMove(id), isTrue);
          final result = engine.tap(id);
          if (level.rotationTiles.contains(result.to)) visited.add(result.to!);
          plain.tap(id);
        }
        expect(engine.isCompleted, isTrue);
        expect(plain.isCompleted, isFalse);
        expect(visited.length, level.rotationTiles.length);
        expect(
          GameEngine(level)..restore(engine.history),
          isA<GameEngine>().having((e) => e.isCompleted, 'replay', true),
        );
        while (engine.canUndo) {
          engine.undo();
        }
        for (final b in level.blocks) {
          expect(engine.blockById(b.id), b);
        }
      }
    },
  );
}
