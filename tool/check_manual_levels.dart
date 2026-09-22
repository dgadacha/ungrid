// Les niveaux écrits à la main tiennent-ils avec la règle du glissement ?
// Usage : dart run tool/check_manual_levels.dart
import 'package:ungrid/game/engine/level_generator.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/levels/manual_levels.dart';
import 'package:ungrid/game/levels/level_pattern.dart';

void main() {
  const solver = LevelSolver();
  var broken = 0;

  print('  id  grille  blocs  coups  repos  sorties  états  ok');
  for (final level in ManualLevels.all()) {
    final result = solver.solve(level);
    final exitable = LevelGenerator.exitableCount(level);
    final ok = result.solvable;
    if (!ok) broken++;

    print('${level.id.toString().padLeft(4)}'
        '  ${'${level.columns}x${level.rows}'.padLeft(5)}'
        '  ${level.blocks.length.toString().padLeft(5)}'
        '  ${result.minimumMoves.toString().padLeft(5)}'
        '  ${(result.minimumMoves - level.blocks.length).toString().padLeft(5)}'
        '  ${exitable.toString().padLeft(7)}'
        '  ${result.exploredStates.toString().padLeft(5)}'
        '  ${ok ? "oui" : "NON"}');

    if (!ok) {
      for (final row in LevelPattern.render(level)) {
        print('        $row');
      }
    }
  }
  print(broken == 0
      ? '\nLes ${ManualLevels.count} niveaux restent jouables.'
      : '\n$broken niveau(x) à refaire.');
}
