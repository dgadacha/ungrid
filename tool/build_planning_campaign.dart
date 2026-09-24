// Variantes déterministes de la campagne v3, filtrées pour la planification.
import 'dart:convert';
import 'dart:io';
import 'package:ungrid/game/engine/slide_generator.dart';
import 'package:ungrid/game/engine/planning_difficulty.dart';
import 'package:ungrid/game/models/level.dart';
import 'package:ungrid/game/engine/game_engine.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/engine/puzzle_analysis.dart';
import 'package:ungrid/game/engine/seeded_random.dart';
import 'package:ungrid/game/models/grid_position.dart';
import 'package:ungrid/game/models/direction.dart';
import 'package:ungrid/game/engine/level_fingerprint.dart';

void main(List<String> args) {
  if (args.isNotEmpty && args.first == '--merge') {
    final unique = <String, Map<String, dynamic>>{};
    for (final path in args.skip(1)) {
      for (final line in File(path).readAsLinesSync()) {
        final raw = jsonDecode(line) as Map<String, dynamic>;
        unique[LevelFingerprint.of(Level.fromJson(raw))] = raw;
      }
    }
    publish(unique.values.toList());
    return;
  }
  final start = args.isEmpty ? 1 : int.parse(args[0]);
  final end = args.length < 2 ? 300000 : int.parse(args[1]);
  Directory('build/planning_campaign').createSync(recursive: true);
  final checkpoint = File('build/planning_campaign/candidates_$start.jsonl');
  if (!checkpoint.existsSync()) checkpoint.writeAsStringSync('');
  const solver = LevelSolver(maxExploredStates: 12000);
  const analyzer = PuzzleAnalyzer(solver: LevelSolver(maxExploredStates: 6000));
  final candidates = <Map<String, dynamic>>[];
  final seen = <String>{};
  var resumeAt = start;
  for (final line in checkpoint.readAsLinesSync()) {
    final raw = jsonDecode(line) as Map<String, dynamic>;
    candidates.add(raw);
    seen.add(LevelFingerprint.of(Level.fromJson(raw)));
    final next = (raw['seed'] as int) + 1;
    if (next > resumeAt) resumeAt = next;
  }
  final sources =
      (jsonDecode(
                File(
                  'assets/levels/campaign_v3_solutions.json',
                ).readAsStringSync(),
              )['levels']
              as List)
          .map((raw) => Level.fromJson(raw as Map<String, dynamic>))
          .toList();
  final old =
      jsonDecode(
            File('assets/levels/campaign_v2.json').readAsStringSync(),
          )['levels']
          as List;
  for (final raw in old) {
    final base = const SlideGenerator().fromSeed(raw['seed'] as int)!;
    sources.add(base.copyWith(stopTiles: [], rotationTiles: base.stopTiles));
  }
  if (args.length >= 3) {
    final refinement =
        jsonDecode(File(args[2]).readAsStringSync())['levels'] as List;
    sources.clear();
    sources.addAll(
      refinement.map((raw) => Level.fromJson(raw as Map<String, dynamic>)),
    );
  }
  for (var seed = resumeAt; seed <= end && candidates.length < 100; seed++) {
    if (seed % 2000 == 0) {
      stdout.writeln('Variantes $seed : ${candidates.length} retenues');
    }
    final random = SeededRandom(seed);
    final base = sources[(seed - 1) % sources.length];
    final tiles = [...base.rotationTiles];
    final tile = GridPosition(
      random.nextInt(base.columns),
      random.nextInt(base.rows),
    );
    if (tiles.contains(tile)) continue;
    if (tiles.length < 3 && random.nextBool()) {
      tiles.add(tile);
    } else {
      tiles[random.nextInt(tiles.length)] = tile;
    }
    final blocks = [...base.blocks];
    for (var mutation = 0; mutation < 1 + seed % 2; mutation++) {
      final index = random.nextInt(blocks.length);
      blocks[index] = blocks[index].copyWith(
        direction: Direction.values[random.nextInt(4)],
      );
    }
    var level = base.copyWith(rotationTiles: tiles, blocks: blocks, seed: seed);
    final solved = solver.solve(level);
    if (!solved.solvable || !solved.exhaustive) continue;
    level = level.copyWith(optimalMoves: solved.minimumMoves);
    final plain = GameEngine(
      level.copyWith(rotationTiles: [], stopTiles: level.rotationTiles),
    );
    for (final id in solved.exampleSolution) {
      plain.tap(id);
    }
    if (plain.isCompleted) continue;
    final planning = PlanningDifficulty.measure(level, solved.exampleSolution);
    if (!planning.accepts || solved.minimumMoves < 16) continue;
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
    if ((candidates.length + 1) % 5 == 0) {
      stdout.writeln(
        '${candidates.length + 1} candidats validés à la seed $seed',
      );
    }
    candidates.add({
      ...level.toJson(),
      'seed': seed,
      'sourceFingerprint': LevelFingerprint.of(base),
      if (args.length >= 3) 'sourceFile': args[2],
      'optimalMoves': solved.minimumMoves,
      'solution': solved.exampleSolution,
      'analysis': analysis.toJson(),
      'planning': planning.toJson(),
    });
    checkpoint.writeAsStringSync(
      '${jsonEncode(candidates.last)}\n',
      mode: FileMode.append,
      flush: true,
    );
  }
  stdout.writeln(
    'Checkpoint : ${checkpoint.path} (${candidates.length} candidats)',
  );
  if (args.isEmpty) publish(candidates);
}

void publish(List<Map<String, dynamic>> candidates) {
  candidates.sort((a, b) {
    final planningOrder = (a['planning']['deferredReturns'] as int).compareTo(
      b['planning']['deferredReturns'] as int,
    );
    if (planningOrder != 0) return planningOrder;
    final scoreOrder = (a['analysis']['difficultyScore'] as num).compareTo(
      b['analysis']['difficultyScore'] as num,
    );
    return scoreOrder != 0
        ? scoreOrder
        : (a['seed'] as int).compareTo(b['seed'] as int);
  });
  if (candidates.length < 100) {
    throw StateError(
      'Seulement ${candidates.length} niveaux : agrandir le pool.',
    );
  }
  final selected = [
    for (var i = 0; i < 100; i++)
      {...candidates[(i * (candidates.length - 1) / 99).round()], 'id': i + 1},
  ];
  if (selected
      .skip(80)
      .any((row) => (row['planning']['deferredReturns'] as int) < 4)) {
    throw StateError(
      'Pas assez de candidats experts : au moins quatre retours différés nécessaires.',
    );
  }
  const output = 'build/planning_campaign';
  Directory(output).createSync(recursive: true);
  final definitions = [
    for (final raw in selected)
      {
        'levelId': raw['id'],
        'seed': raw['seed'],
        'generatorVersion': 4,
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
  File('$output/campaign_v4.json').writeAsStringSync(
    '${encoder.convert({'catalogVersion': 4, 'generatorVersion': 4, 'levelCount': 100, 'mechanic': 'rotation-planning-v1', 'levels': definitions})}\n',
  );
  File(
    '$output/campaign_v4_solutions.json',
  ).writeAsStringSync('${encoder.convert({'levels': selected})}\n');
  stdout.writeln('${candidates.length} candidats, 100 niveaux exportés.');
}
