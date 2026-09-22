// Statistiques sur les niveaux générés.
// Usage : dart run tool/analyze_generated.dart [nombre]
import 'package:ungrid/game/engine/difficulty_config.dart';
import 'package:ungrid/game/engine/level_generator.dart';
import 'package:ungrid/game/levels/level_pattern.dart';

void main(List<String> args) {
  final total = args.isEmpty ? 200 : int.parse(args.first);
  const generator = LevelGenerator();
  const fields = 9;
  final bands = <String, List<double>>{};

  var replies = 0;
  var unsolvable = 0;
  var withReposition = 0;
  var sealed = 0;
  final watch = Stopwatch()..start();
  final durations = <int>[];

  for (var id = 21; id <= 20 + total; id++) {
    final lap = Stopwatch()..start();
    final generated = generator.generate(levelId: id);
    durations.add(lap.elapsedMicroseconds);

    if (!generated.accepted) replies++;
    if (!generated.solveResult.solvable) unsolvable++;
    if (generated.solveResult.minimumMoves > generated.level.blocks.length) {
      withReposition++;
    }
    if (generated.difficulty.exitableRatio == 0) sealed++;

    final band = bandFor(id);
    bands.putIfAbsent(band.name, () => []).addAll([
      generated.level.blocks.length.toDouble(),
      generated.analysis.moveComplexity,
      generated.analysis.multiMoveRatio,
      generated.analysis.averageChoices,
      generated.analysis.wrongMoveOpportunities.toDouble(),
      generated.analysis.deadEndOpportunities.toDouble(),
      generated.analysis.decisionScore,
      generated.difficulty.exitableRatio,
      generated.attempts.toDouble(),
    ]);

    if (id <= 24 || id % 137 == 0) {
      print('--- niveau $id : $generated');
      for (final row in LevelPattern.render(generated.level)) {
        print('    $row');
      }
    }
  }
  watch.stop();

  print('\ntranche                blocs  coups/bloc  rejoués  choix  erreurs'
      '  pièges  décision  sorties  essais');
  for (final entry in bands.entries) {
    final values = entry.value;
    final rows = values.length ~/ fields;
    double avg(int offset) {
      var sum = 0.0;
      for (var i = 0; i < rows; i++) {
        sum += values[i * fields + offset];
      }
      return sum / rows;
    }

    print('${entry.key.padRight(21)}'
        '  ${avg(0).toStringAsFixed(1).padLeft(5)}'
        '  ${avg(1).toStringAsFixed(2).padLeft(10)}'
        '  ${'${(avg(2) * 100).round()} %'.padLeft(7)}'
        '  ${avg(3).toStringAsFixed(1).padLeft(5)}'
        '  ${avg(4).toStringAsFixed(1).padLeft(7)}'
        '  ${avg(5).toStringAsFixed(1).padLeft(6)}'
        '  ${avg(6).toStringAsFixed(0).padLeft(8)}'
        '  ${'${(avg(7) * 100).round()} %'.padLeft(7)}'
        '  ${avg(8).toStringAsFixed(1).padLeft(6)}');
  }

  durations.sort();
  print('\nrepositionnement exigé : $withReposition/$total'
      '   aucune sortie offerte : $sealed/$total');
  print('replis : $replies/$total   insolubles : $unsolvable');
  print('génération : moyenne ${(watch.elapsedMilliseconds / total).toStringAsFixed(1)} ms, '
      'médiane ${(durations[durations.length ~/ 2] / 1000).toStringAsFixed(1)} ms, '
      'p95 ${(durations[(durations.length * 0.95).floor()] / 1000).toStringAsFixed(1)} ms, '
      'max ${(durations.last / 1000).toStringAsFixed(1)} ms');
}
