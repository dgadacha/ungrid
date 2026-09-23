// Ce que les niveaux demandent vraiment au joueur : décisions, erreurs
// possibles, repositionnements. Le nombre de coups ne dit presque rien.
//
// Usage : dart run tool/measure_decisions.dart [niveaux] [essais]
import 'package:ungrid/game/engine/difficulty_config.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/engine/puzzle_analysis.dart';
import 'package:ungrid/game/engine/seeded_random.dart';
import 'package:ungrid/game/engine/slide_generator.dart';

void main(List<String> args) {
  final levels = args.isEmpty ? 30 : int.parse(args.first);
  final tries = args.length < 2 ? 12 : int.parse(args[1]);

  const generator = SlideGenerator();
  const solver = LevelSolver();
  const analyzer = PuzzleAnalyzer();

  var count = 0;
  var complexity = 0.0, multi = 0.0, choices = 0.0, decisions = 0.0;
  var wrong = 0.0, dead = 0.0, stops = 0.0, score = 0.0;
  var bestScore = 0.0;
  String? best;
  final watch = Stopwatch()..start();

  for (var id = 21; id < 21 + levels; id++) {
    final config = DifficultyCurve.configFor(id);
    for (var attempt = 0; attempt < tries; attempt++) {
      final level = generator.buildCandidate(
        levelId: id,
        seed: seedForLevel(id, attempt),
        config: config,
      );
      if (level == null) continue;
      final result = solver.solve(level);
      if (!result.solvable) continue;

      final analysis = analyzer.analyse(level, result);
      count++;
      complexity += analysis.moveComplexity;
      multi += analysis.multiMoveRatio;
      choices += analysis.averageChoices;
      decisions += analysis.decisionRatio;
      wrong += analysis.wrongMoveOpportunities;
      dead += analysis.deadEndOpportunities;
      stops += analysis.stopTileInteractions.toDouble();
      score += analysis.decisionScore;

      if (analysis.decisionScore > bestScore) {
        bestScore = analysis.decisionScore;
        best = '$id/$attempt : ${level.blocks.length} blocs, '
            '${result.minimumMoves} coups, $analysis';
      }
    }
  }
  watch.stop();

  if (count == 0) {
    print('aucun candidat');
    return;
  }
  void line(String label, double value, [int digits = 2]) =>
      print('  ${label.padRight(28)} ${value.toStringAsFixed(digits)}');

  print('$count candidats analysés en ${watch.elapsedMilliseconds} ms '
      '(${(watch.elapsedMilliseconds / count).toStringAsFixed(1)} ms pièce)\n');
  line('coups / blocs', complexity / count);
  line('blocs rejoués (part)', multi / count);
  line('choix moyens par étape', choices / count);
  line('étapes avec un choix (part)', decisions / count);
  line('coups qui rallongent', wrong / count, 1);
  line('coups qui condamnent', dead / count, 1);
  line('arrêts sur tuile', stops / count, 1);
  line('note de décision', score / count, 1);
  print('\nmeilleur : $best');
}
