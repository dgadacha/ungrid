// Existe-t-il des puzzles où le rapport coups / blocs dépasse 1,25 ?
//
// Question de fond, pas de réglage : un bloc ne peut être joué deux fois que
// s'il est pris dans un blocage circulaire, et le plus petit en compte quatre.
// On tire donc des boards au hasard, on les résout, et on regarde le plafond
// réellement atteint.
//
// Usage : dart run tool/search_ceiling.dart [tirages]
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/engine/seeded_random.dart';
import 'package:ungrid/game/levels/level_pattern.dart';
import 'package:ungrid/game/models/block.dart';
import 'package:ungrid/game/models/direction.dart';
import 'package:ungrid/game/models/grid_position.dart';
import 'package:ungrid/game/models/level.dart';

void main(List<String> args) {
  final draws = args.isEmpty ? 40000 : int.parse(args.first);
  const solver = LevelSolver(maxExploredStates: 6000);

  var best = 0.0;
  Level? bestLevel;
  var bestMoves = 0;
  final buckets = <String, int>{};
  var solvable = 0;

  for (var draw = 0; draw < draws; draw++) {
    final random = SeededRandom(draw * 2654435761 + 7);
    final size = 4 + random.nextInt(3);
    final blockCount = 3 + random.nextInt(6);

    final taken = <int>{};
    final blocks = <Block>[];
    for (var i = 0; i < blockCount; i++) {
      final cell = random.nextInt(size * size);
      if (!taken.add(cell)) continue;
      blocks.add(Block(
        id: 'b${blocks.length}',
        position: GridPosition(cell % size, cell ~/ size),
        direction: Direction.values[random.nextInt(4)],
      ));
    }
    if (blocks.length < 3) continue;

    final level = Level(
      id: draw,
      rows: size,
      columns: size,
      blocks: blocks,
      optimalMoves: blocks.length,
    );

    final result = solver.solve(level);
    if (!result.solvable) continue;
    solvable++;

    final complexity = result.minimumMoves / blocks.length;
    final key = switch (complexity) {
      < 1.01 => '1.00',
      < 1.15 => '1.01-1.14',
      < 1.26 => '1.15-1.25',
      < 1.40 => '1.26-1.39',
      < 1.60 => '1.40-1.59',
      _ => '1.60+',
    };
    buckets[key] = (buckets[key] ?? 0) + 1;

    if (complexity > best) {
      best = complexity;
      bestLevel = level;
      bestMoves = result.minimumMoves;
    }
  }

  print('$solvable boards solvables sur $draws tirages\n');
  for (final key in ['1.00', '1.01-1.14', '1.15-1.25', '1.26-1.39', '1.40-1.59', '1.60+']) {
    final count = buckets[key] ?? 0;
    final share = solvable == 0 ? 0 : count * 100 / solvable;
    print('  ${key.padRight(10)} ${count.toString().padLeft(6)}  '
        '${share.toStringAsFixed(2)} %');
  }

  print('\nplafond atteint : ${best.toStringAsFixed(2)}');
  if (bestLevel != null) {
    print('  ${bestLevel.blocks.length} blocs, $bestMoves coups');
    for (final row in LevelPattern.render(bestLevel)) {
      print('    $row');
    }
  }
}
