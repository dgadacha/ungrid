// Distribution de la complexité des candidats produits par le générateur.
//
// La question : le rembobinage peut-il seulement produire des niveaux où un
// bloc doit être joué plusieurs fois ? Tant qu'on ne le sait pas, régler les
// seuils n'a pas de sens.
//
// Usage : dart run tool/measure_complexity.dart [niveaux] [essais par niveau]
import 'package:ungrid/game/engine/difficulty_config.dart';
import 'package:ungrid/game/engine/level_generator.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/engine/seeded_random.dart';
import 'package:ungrid/game/engine/slide_generator.dart';

void main(List<String> args) {
  final levels = args.isEmpty ? 40 : int.parse(args.first);
  final tries = args.length < 2 ? 30 : int.parse(args[1]);

  const generator = SlideGenerator();
  const solver = LevelSolver();

  final buckets = <String, int>{};
  final exitBuckets = <String, int>{};
  var best = 0.0;
  String? bestBoard;
  var total = 0;
  var solvable = 0;

  for (var id = 21; id < 21 + levels; id++) {
    final config = DifficultyCurve.configFor(id);
    for (var attempt = 0; attempt < tries; attempt++) {
      final level = generator.buildCandidate(
        levelId: id,
        seed: seedForLevel(id, attempt),
        config: config,
      );
      if (level == null) continue;
      total++;

      final result = solver.solve(level);
      if (!result.solvable) continue;
      solvable++;

      final complexity = result.minimumMoves / level.blocks.length;
      final key = switch (complexity) {
        < 1.01 => '1.00',
        < 1.10 => '1.01-1.09',
        < 1.20 => '1.10-1.19',
        < 1.30 => '1.20-1.29',
        < 1.50 => '1.30-1.49',
        _ => '1.50+',
      };
      buckets[key] = (buckets[key] ?? 0) + 1;

      final exit = LevelGenerator.exitableCount(level) / level.blocks.length;
      final exitKey = switch (exit) {
        <= 0.001 => '0 %',
        < 0.11 => '1-10 %',
        < 0.21 => '11-20 %',
        < 0.31 => '21-30 %',
        _ => '31 %+',
      };
      exitBuckets[exitKey] = (exitBuckets[exitKey] ?? 0) + 1;

      if (complexity > best) {
        best = complexity;
        bestBoard =
            '$id/$attempt : ${level.blocks.length} blocs, '
            '${result.minimumMoves} coups';
      }
    }
  }

  print('candidats : $total, solvables : $solvable\n');
  print('complexité (coups / blocs)');
  for (final key in [
    '1.00',
    '1.01-1.09',
    '1.10-1.19',
    '1.20-1.29',
    '1.30-1.49',
    '1.50+',
  ]) {
    final count = buckets[key] ?? 0;
    final share = solvable == 0 ? 0 : (count * 100 / solvable).round();
    print(
      '  ${key.padRight(10)} ${count.toString().padLeft(5)}  ${'#' * (share ~/ 2)} $share %',
    );
  }

  print('\nsorties immédiates');
  for (final key in ['0 %', '1-10 %', '11-20 %', '21-30 %', '31 %+']) {
    final count = exitBuckets[key] ?? 0;
    final share = solvable == 0 ? 0 : (count * 100 / solvable).round();
    print(
      '  ${key.padRight(10)} ${count.toString().padLeft(5)}  ${'#' * (share ~/ 2)} $share %',
    );
  }

  print('\nmeilleur : ${best.toStringAsFixed(2)}  ($bestBoard)');
}
