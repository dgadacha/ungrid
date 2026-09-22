// Tout ce qu'on sait d'un niveau donné.
// Usage : dart run tool/inspect_level.dart 43
import 'package:ungrid/game/engine/difficulty_config.dart';
import 'package:ungrid/game/engine/level_generator.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/engine/puzzle_analysis.dart';
import 'package:ungrid/game/levels/level_pattern.dart';
import 'package:ungrid/game/levels/manual_levels.dart';

void main(List<String> args) {
  final ids = args.isEmpty ? [43] : args.map(int.parse);
  const generator = LevelGenerator();
  const solver = LevelSolver();
  const analyzer = PuzzleAnalyzer();

  for (final id in ids) {
    final band = bandFor(id);
    print('=== niveau $id — tranche « ${band.name} »');

    if (ManualLevels.contains(id)) {
      final level = ManualLevels.byId(id);
      final result = solver.solve(level);
      final analysis = analyzer.analyse(level, result);
      _show(level.blocks.length, result.minimumMoves, level.moveLimit, analysis);
      for (final row in LevelPattern.render(level)) {
        print('    $row');
      }
      continue;
    }

    final watch = Stopwatch()..start();
    final generated = generator.generate(levelId: id);
    watch.stop();

    _show(
      generated.level.blocks.length,
      generated.solveResult.minimumMoves,
      generated.level.moveLimit,
      generated.analysis,
    );
    print('  attendu             coups/bloc ${band.minComplexity}'
        '-${band.maxComplexity}, rejoués >= ${(band.minMultiMoveRatio * 100).round()} %'
        ', décision >= ${band.minDecisionScore.round()}');
    print('  essais              ${generated.attempts}'
        '${generated.accepted ? " (accepté)" : " (meilleur trouvé)"}'
        ' en ${watch.elapsedMilliseconds} ms');
    for (final row in LevelPattern.render(generated.level)) {
      print('    $row');
    }
  }
}

void _show(int blocks, int moves, int limit, PuzzleAnalysis analysis) {
  print('  blocs               $blocks');
  print('  coups optimaux      $moves  (limite $limit)');
  print('  coups / bloc        ${analysis.moveComplexity.toStringAsFixed(2)}');
  print('  blocs rejoués       ${analysis.multiMoveBlocks}'
      ' (${(analysis.multiMoveRatio * 100).round()} %)');
  print('  choix par étape     ${analysis.averageChoices.toStringAsFixed(1)}');
  print('  étapes avec choix   ${(analysis.decisionRatio * 100).round()} %');
  print('  coups qui rallongent ${analysis.wrongMoveOpportunities}');
  print('  coups qui condamnent ${analysis.deadEndOpportunities}');
  print('  note de décision    ${analysis.decisionScore.round()}');
}
