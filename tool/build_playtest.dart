// dart compile exe tool/build_playtest.dart -o /tmp/ungrid-playtest
// /tmp/ungrid-playtest [nombre de seeds, 6000 par défaut]
// Produit une proposition dans build/playtest/. Les assets retenus sont
// copiés explicitement après vérification : jamais de remplacement implicite.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:ungrid/game/campaign/campaign_level.dart';
import 'package:ungrid/game/campaign/playtest_plan.dart';
import 'package:ungrid/game/engine/board_quality_evaluator.dart';
import 'package:ungrid/game/engine/generator_version.dart';
import 'package:ungrid/game/engine/level_fingerprint.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/engine/puzzle_analysis.dart';
import 'package:ungrid/game/engine/slide_generator.dart';
import 'package:ungrid/game/engine/solve_result.dart';
import 'package:ungrid/game/models/difficulty.dart';
import 'package:ungrid/game/models/level.dart';

Future<void> main(List<String> args) async {
  final count = args.isEmpty ? 6000 : int.parse(args.single);
  if (count < 20) throw ArgumentError('Au moins vingt seeds sont nécessaires.');
  final workers = math.min(8, Platform.numberOfProcessors);
  stdout.writeln('Analyse de $count seeds sur $workers workers…');
  final batches = await Future.wait([
    for (var w = 0; w < workers; w++)
      Isolate.run(() => evaluate(w + 1, count, workers)),
  ]);
  final pool = batches.expand((batch) => batch).toList();
  stdout.writeln('${pool.length} candidats entièrement analysés.');

  final used = <String>{};
  final selected = <int, Candidate>{};
  final order = List.generate(20, (i) => i)
    ..sort(
      (a, b) => PlaytestPlan.stages[b].targetScore.compareTo(
        PlaytestPlan.stages[a].targetScore,
      ),
    );
  for (final index in order) {
    final stage = PlaytestPlan.stages[index];
    final eligible =
        pool
            .where((c) => !used.contains(c.fingerprint) && fits(c, stage))
            .toList()
          ..sort((a, b) {
            final distance = (a.analysis.difficultyScore() - stage.targetScore)
                .abs()
                .compareTo(
                  (b.analysis.difficultyScore() - stage.targetScore).abs(),
                );
            return distance != 0 ? distance : a.seed.compareTo(b.seed);
          });
    if (eligible.isEmpty) {
      throw StateError(
        'Aucun candidat pour le niveau ${index + 1}. Augmenter le pool ; aucun seuil ne sera relâché.',
      );
    }
    selected[index + 1] = eligible.first;
    used.add(eligible.first.fingerprint);
  }

  final levels = <CampaignLevel>[];
  final reports = <Map<String, dynamic>>[];
  final solutions = <Map<String, dynamic>>[];
  for (var id = 1; id <= 20; id++) {
    final c = selected[id]!;
    final score = c.analysis.difficultyScore();
    levels.add(
      CampaignLevel(
        levelId: id,
        seed: c.seed,
        generatorVersion: currentGeneratorVersion,
        difficulty: score < 45
            ? Difficulty.easy
            : score < 58
            ? Difficulty.medium
            : score < 68
            ? Difficulty.hard
            : Difficulty.expert,
        difficultyScore: score,
        optimalMoves: c.solution.minimumMoves,
        fingerprint: c.fingerprint,
      ),
    );
    reports.add({
      'levelId': id,
      'seed': c.seed,
      'chapter': PlaytestPlan.chapterFor(id),
      'phase': id <= 5 ? 'Introduction' : PlaytestPlan.phaseFor(id),
      'targetScore': PlaytestPlan.stages[id - 1].targetScore,
      'gridSize': c.level.columns,
      'visualScore': c.visualScore,
      ...c.analysis.toJson(),
    });
    solutions.add({'levelId': id, 'solution': c.solution.exampleSolution});
    stdout.writeln(
      '$id : seed ${c.seed}, ${c.level.blocks.length} blocs, ${c.solution.minimumMoves} coups, score ${score.toStringAsFixed(1)}',
    );
  }
  const encoder = JsonEncoder.withIndent('  ');
  Directory('build/playtest').createSync(recursive: true);
  void write(String suffix, Object data) => File(
    'build/playtest/playtest_v1$suffix.json',
  ).writeAsStringSync('${encoder.convert(data)}\n');
  write(
    '',
    Campaign(
      catalogVersion: 1,
      generatorVersion: currentGeneratorVersion,
      levels: levels,
    ).toJson(),
  );
  write('_report', {
    'candidateSeeds': count,
    'eligibleCandidates': pool.length,
    'levels': reports,
  });
  write('_solutions', {'levels': solutions});
}

bool fits(Candidate c, PlaytestStage stage) {
  final a = c.analysis;
  return c.level.blocks.length >= stage.minBlocks &&
      c.level.blocks.length <= stage.maxBlocks &&
      c.level.stopTiles.length >= stage.minStops &&
      c.level.stopTiles.length <= stage.maxStops &&
      (a.difficultyScore() - stage.targetScore).abs() <= 4 &&
      a.optimalPathNarrowness >= stage.minNarrowness &&
      a.temptingWrongMoveRatio >= stage.minWrongRatio &&
      a.dependencyComplexity >= stage.minDependency &&
      a.trivialityPenalty <= stage.maxTriviality;
}

List<Candidate> evaluate(int start, int end, int stride) {
  const generator = SlideGenerator();
  const solver = LevelSolver(maxExploredStates: 60000);
  const analyzer = PuzzleAnalyzer(solver: LevelSolver(maxExploredStates: 6000));
  const quality = BoardQualityEvaluator();
  final result = <Candidate>[];
  for (var seed = start; seed <= end; seed += stride) {
    final level = generator.fromSeed(seed);
    if (level == null ||
        !level.isStructurallyValid ||
        level.blocks.length > 14 ||
        level.columns > 6 ||
        level.stopTiles.length > 2) {
      continue;
    }
    final visual = quality.evaluate(level).score;
    if (visual < 55) continue;
    final solution = solver.solve(level);
    if (!solution.solvable || !solution.exhaustive) continue;
    final analysis = analyzer.analyse(level, solution);
    if (analysis.unresolvedAlternatives != 0 ||
        analysis.unusedStopTileCount != 0) {
      continue;
    }
    result.add(Candidate(seed, level, solution, analysis, visual));
  }
  return result;
}

class Candidate {
  Candidate(
    this.seed,
    this.level,
    this.solution,
    this.analysis,
    this.visualScore,
  ) : fingerprint = LevelFingerprint.of(level);
  final int seed;
  final Level level;
  final SolveResult solution;
  final PuzzleAnalysis analysis;
  final double visualScore;
  final String fingerprint;
}
