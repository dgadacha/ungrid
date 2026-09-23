// Génère un lot d'essai distinct, sans modifier la campagne publiée.
import 'dart:convert';
import 'dart:io';
import 'package:ungrid/game/engine/game_engine.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/engine/puzzle_analysis.dart';
import 'package:ungrid/game/engine/rotation_generator.dart';
import 'package:ungrid/game/engine/level_fingerprint.dart';

void main() {
  const solver = LevelSolver(maxExploredStates: 12000);
  const analyzer = PuzzleAnalyzer(solver: LevelSolver(maxExploredStates: 6000));
  final candidates = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (var seed = 1; seed <= 12000 && candidates.length < 30; seed++) {
    final level = const RotationGenerator().fromSeed(seed);
    if (level == null) continue;
    final solved = solver.solve(level);
    final analysis = analyzer.analyse(level, solved);
    if (analysis.unresolvedAlternatives != 0 ||
        analysis.unusedStopTileCount != 0 ||
        analysis.difficultyScore() < 60 ||
        analysis.trivialityPenalty > .25) {
      continue;
    }
    final engine = GameEngine(level);
    for (final id in solved.exampleSolution) {
      engine.tap(id);
    }
    if (!engine.isCompleted || !seen.add(LevelFingerprint.of(level))) {
      continue;
    }
    candidates.add({
      ...level.toJson(),
      'seed': seed,
      'optimalMoves': solved.minimumMoves,
      'solution': solved.exampleSolution,
      'analysis': analysis.toJson(),
    });
  }
  candidates.sort(
    (a, b) => (a['analysis']['difficultyScore'] as double).compareTo(
      b['analysis']['difficultyScore'] as double,
    ),
  );
  if (candidates.length < 10) {
    throw StateError(
      'Seulement ${candidates.length} niveaux : agrandir le pool.',
    );
  }
  final selected = [
    for (var i = 0; i < 10; i++)
      {...candidates[(i * (candidates.length - 1) / 9).round()], 'id': i + 1},
  ];
  Directory('build/rotation').createSync(recursive: true);
  File('build/rotation/rotation_v1.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'rulesVersion': 1, 'levels': selected})}\n',
  );
  stdout.writeln('${candidates.length} candidats, 10 niveaux exportés.');
}
