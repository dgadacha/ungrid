import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ungrid/game/engine/game_engine.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/levels/level_pattern.dart';
import 'package:ungrid/game/models/grid_position.dart';
import 'package:ungrid/game/models/level.dart';

Level crossing() => LevelPattern.parse(
  ['.v..', '>...', '....', '....'],
  id: 1,
).copyWith(fragileStopTiles: [const GridPosition(1, 1)], optimalMoves: 3);

void main() {
  test('le premier bloc est retenu ; sa sortie libère le trajet suivant', () {
    final level = crossing();
    final engine = GameEngine(level);
    final a = engine.blockAt(0, 1)!.id;
    final b = engine.blockAt(1, 0)!.id;
    expect(engine.tap(a).stopped, isTrue);
    expect(engine.hasStopTileAt(1, 1), isTrue);
    expect(engine.tap(a).exited, isTrue);
    expect(engine.hasStopTileAt(1, 1), isFalse);
    expect(const LevelSolver().nextBestMove(level, engine.history), b);
    expect(engine.tap(b).exited, isTrue);
    expect(engine.isCompleted, isTrue);
    engine.undo();
    expect(engine.hasStopTileAt(1, 1), isFalse);
    engine.undo();
    expect(engine.hasStopTileAt(1, 1), isTrue);
    expect(engine.blockAt(1, 1)!.id, a);
    engine.undo();
    expect(engine.blockAt(0, 1)!.id, a);
    engine.reset();
    expect(engine.hasStopTileAt(1, 1), isTrue);
  });

  test('un refus ne consomme pas la tuile occupée', () {
    final level = LevelPattern.parse([
      '....',
      '.>>.',
      '....',
      '....',
    ], id: 1).copyWith(fragileStopTiles: [const GridPosition(1, 1)]);
    final engine = GameEngine(level);
    expect(engine.tap(engine.blockAt(1, 1)!.id).blocked, isTrue);
    expect(engine.hasStopTileAt(1, 1), isTrue);
  });

  test('le solveur distingue la tuile consommée et retrouve le minimum', () {
    final level = crossing();
    final solved = const LevelSolver().solve(level);
    expect(solved.minimumMoves, 3);
    final permanent = level.copyWith(
      stopTiles: level.fragileStopTiles,
      fragileStopTiles: [],
    );
    expect(const LevelSolver().solve(permanent).minimumMoves, 4);
    // Oracle en largeur utilisant uniquement le moteur public.
    final queue = <List<String>>[[]];
    final seen = <String>{};
    int? minimum;
    for (var i = 0; i < queue.length; i++) {
      final sequence = queue[i];
      final engine = GameEngine(level);
      for (final id in sequence) {
        engine.tap(id);
      }
      final key =
          '${engine.remainingBlocks.map((b) => '${b.id}:${b.x},${b.y}').join(';')}|${engine.activeStopTiles.join(';')}';
      if (!seen.add(key)) continue;
      if (engine.isCompleted) {
        minimum = sequence.length;
        break;
      }
      for (final b in engine.movableBlocks()) {
        queue.add([...sequence, b.id]);
      }
    }
    expect(solved.minimumMoves, minimum);
  });

  test(
    'les dix niveaux utilisent la disparition et se résolvent au budget publié',
    () {
      final data =
          jsonDecode(File('assets/levels/fragile_v1.json').readAsStringSync())
              as Map;
      expect((data['levels'] as List).length, 10);
      for (final raw in data['levels'] as List) {
        final level = Level.fromJson(raw as Map<String, dynamic>);
        expect(level.isStructurallyValid, isTrue);
        final solved = const LevelSolver(maxExploredStates: 12000).solve(level);
        expect(solved.solvable, isTrue);
        expect(solved.minimumMoves, level.optimalMoves);
        final permanent = level.copyWith(
          stopTiles: level.fragileStopTiles,
          fragileStopTiles: [],
        );
        expect(
          const LevelSolver(
            maxExploredStates: 12000,
          ).solve(permanent).minimumMoves,
          greaterThan(level.optimalMoves),
        );
        final engine = GameEngine(level);
        for (final id in (raw['solution'] as List).cast<String>()) {
          expect(engine.canMove(id), isTrue);
          engine.tap(id);
        }
        expect(engine.isCompleted, isTrue);
        expect(engine.activeStopTiles, isEmpty);
        final replay = GameEngine(level)..restore(engine.history);
        expect(replay.isCompleted, isTrue);
        expect(replay.activeStopTiles, isEmpty);
        while (engine.canUndo) {
          engine.undo();
        }
        expect(engine.activeStopTiles.length, level.fragileStopTiles.length);
        expect(engine.remainingCount, level.blocks.length);
      }
    },
  );
}
