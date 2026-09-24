// Diagnostic du rembobinage : ce que la construction promet, ce que le
// solveur trouve réellement.
import 'package:ungrid/game/engine/difficulty_config.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/engine/seeded_random.dart';
import 'package:ungrid/game/engine/slide_generator.dart';
import 'package:ungrid/game/levels/level_pattern.dart';
import 'package:ungrid/game/models/level.dart';

int exitable(Level level) {
  final busy = <int>{for (final b in level.blocks) b.y * level.columns + b.x};
  var count = 0;
  for (final block in level.blocks) {
    var x = block.x + block.direction.dx;
    var y = block.y + block.direction.dy;
    var clear = true;
    while (x >= 0 && y >= 0 && x < level.columns && y < level.rows) {
      if (busy.contains(y * level.columns + x)) {
        clear = false;
        break;
      }
      x += block.direction.dx;
      y += block.direction.dy;
    }
    if (clear) count++;
  }
  return count;
}

void main() {
  const generator = SlideGenerator();
  const solver = LevelSolver();

  for (final id in [25, 40, 60, 90]) {
    final config = DifficultyCurve.configFor(id);
    print('\n=== niveau $id — $config');
    for (var attempt = 0; attempt < 3; attempt++) {
      final level = generator.buildCandidate(
        levelId: id,
        seed: seedForLevel(id, attempt),
        config: config,
      );
      if (level == null) {
        print('  essai $attempt : aucun candidat');
        continue;
      }
      final result = solver.solve(level);
      print(
        '  essai $attempt : ${level.blocks.length} blocs, '
        'construction ${level.optimalMoves} coups, '
        'solveur ${result.minimumMoves} coups, '
        'sorties immédiates ${exitable(level)}, '
        'impasses ${result.deadEndCount}, '
        'états ${result.exploredStates}',
      );
      if (attempt == 0) {
        for (final row in LevelPattern.render(level)) {
          print('      $row');
        }
      }
    }
  }
}
