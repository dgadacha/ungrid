// Génère une proposition de campagne rotation v3 dans build/.
import 'dart:convert';
import 'dart:io';
import 'package:ungrid/game/models/level.dart';
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
  for (var seed = 1; seed <= 60000 && candidates.length < 250; seed++) {
    final level = const RotationGenerator().fromSeed(seed);
    if (level == null || level.blocks.length < 7) continue;
    final solved = solver.solve(level);
    final analysis = analyzer.analyse(level, solved);
    if (analysis.unresolvedAlternatives != 0 ||
        analysis.unusedStopTileCount != 0 ||
        analysis.difficultyScore() < 60 ||
        analysis.trivialityPenalty > .2 ||
        analysis.optimalPathNarrowness < .35 ||
        analysis.temptingWrongMoveRatio < .5 ||
        analysis.dependencyComplexity < .65) {
      continue;
    }
    final engine = GameEngine(level);
    for (final id in solved.exampleSolution) {
      engine.tap(id);
    }
    if (!engine.isCompleted || !seen.add(LevelFingerprint.of(level))) {
      continue;
    }
    if ((candidates.length + 1) % 25 == 0) {
      stdout.writeln(
        '${candidates.length + 1} candidats validés à la seed $seed',
      );
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
  if (candidates.length < 100) {
    throw StateError(
      'Seulement ${candidates.length} niveaux : agrandir le pool.',
    );
  }
  final selected = [
    for (var i = 0; i < 100; i++)
      {...candidates[(i * (candidates.length - 1) / 99).round()], 'id': i + 1},
  ];
  const output = 'build/rotation_campaign';
  Directory(output).createSync(recursive: true);
  final definitions = [
    for (final raw in selected)
      {
        'levelId': raw['id'],
        'seed': raw['seed'],
        'generatorVersion': 3,
        'difficulty': (raw['id'] as int) <= 20
            ? 'medium'
            : (raw['id'] as int) <= 70
            ? 'hard'
            : 'expert',
        'difficultyScore': raw['analysis']['difficultyScore'],
        'optimalMoves': raw['optimalMoves'],
        'status': 'active',
        'fingerprint': LevelFingerprint.of(Level.fromJson(raw)),
        'board': {
          for (final key in [
            'id',
            'rows',
            'columns',
            'blocks',
            'rotationTiles',
          ])
            key: raw[key],
        },
      },
  ];
  const encoder = JsonEncoder.withIndent('  ');
  File('$output/campaign_v3.json').writeAsStringSync(
    '${encoder.convert({'catalogVersion': 3, 'generatorVersion': 3, 'levelCount': 100, 'mechanic': 'rotation-v1', 'levels': definitions})}\n',
  );
  File(
    '$output/campaign_v3_solutions.json',
  ).writeAsStringSync('${encoder.convert({'levels': selected})}\n');
  stdout.writeln('${candidates.length} candidats, 100 niveaux exportés.');
}
