import 'package:ungrid/game/engine/difficulty_config.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/engine/seeded_random.dart';
import 'package:ungrid/game/engine/slide_generator.dart';
import 'package:ungrid/game/levels/level_pattern.dart';

void main() {
  const solver = LevelSolver();
  var ok = 0, total = 0;
  for (var seed = 0; seed < 12; seed++) {
    final level = SlideGenerator.debugKnotOnly(
      seed: seedForLevel(30, seed),
      config: DifficultyCurve.configFor(30),
    );
    if (level == null) continue;
    total++;
    final r = solver.solve(level);
    final complexity = r.solvable ? r.minimumMoves / level.blocks.length : 0;
    if (r.solvable && r.minimumMoves > level.blocks.length) ok++;
    print('seed $seed : ${level.blocks.length} blocs, '
        '${r.solvable ? "${r.minimumMoves} coups" : "INSOLUBLE"}, '
        'complexité ${complexity.toStringAsFixed(2)}');
    for (final row in LevelPattern.render(level)) {
      print('    $row');
    }
  }
  print('\nnoeuds qui forcent un second coup : $ok/$total');
}
