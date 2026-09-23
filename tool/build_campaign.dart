// Fabrique la campagne officielle.
//
// La génération procédurale ne sert qu'à produire du contenu : le joueur, lui,
// reçoit une liste figée. On tire donc un très grand nombre de candidats, on
// les éprouve tous, et on ne retient que les meilleurs — un niveau correct mais
// sans intérêt n'a pas sa place dans une campagne qu'on publie.
//
//   dart run tool/build_campaign.dart [candidats] [niveaux]
//
// Compiler en natif pour un lot complet : en mode debug, tout est plusieurs
// fois plus lent.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:ungrid/game/campaign/campaign_level.dart';
import 'package:ungrid/game/engine/board_quality_evaluator.dart';
import 'package:ungrid/game/engine/difficulty_config.dart';
import 'package:ungrid/game/engine/difficulty_evaluator.dart';
import 'package:ungrid/game/engine/generator_version.dart';
import 'package:ungrid/game/engine/level_fingerprint.dart';
import 'package:ungrid/game/engine/level_generator.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/engine/puzzle_analysis.dart';
import 'package:ungrid/game/engine/slide_generator.dart';
import 'package:ungrid/game/models/difficulty.dart';

const int catalogVersion = 1;

/// Candidats retenus quand la tranche n'a personne à sa mesure.
const int _fallbackShortlist = 250;

Future<void> main(List<String> args) async {
  final candidateCount = args.isEmpty ? 100000 : int.parse(args.first);
  final levelCount = args.length < 2 ? 100 : int.parse(args[1]);
  final workers = Platform.numberOfProcessors.clamp(1, 12);

  stdout.writeln('UNGRID — campagne v$catalogVersion '
      '(générateur v$currentGeneratorVersion)');
  stdout.writeln('$candidateCount candidats sur $workers coeurs, '
      'pour $levelCount niveaux\n');

  final watch = Stopwatch()..start();
  final slice = (candidateCount / workers).ceil();
  final batches = await Future.wait([
    for (var w = 0; w < workers; w++)
      Isolate.run(() => _evaluate(w * slice, slice)),
  ]);
  final pool = [for (final batch in batches) ...batch];
  watch.stop();

  stdout.writeln('${pool.length} candidats retenus sur $candidateCount '
      'en ${(watch.elapsedMilliseconds / 1000).toStringAsFixed(1)} s');

  // Deux boards identiques ne doivent pas se retrouver à deux endroits de la
  // campagne : le joueur reconnaîtrait la grille.
  final seen = <String>{};
  final unique = [
    for (final candidate in pool)
      if (seen.add(candidate.fingerprint)) candidate,
  ];
  stdout.writeln('${unique.length} boards distincts');
  _poolProfile(unique);

  final selection = _select(unique, levelCount);
  _report(selection);
  await _export(selection);
}

/// Évalue une plage de seeds. Tourne dans un isolate.
List<_Candidate> _evaluate(int from, int count) {
  const generator = SlideGenerator();
  const solver = LevelSolver();
  const analyzer = PuzzleAnalyzer();
  const quality = BoardQualityEvaluator();
  const difficulty = DifficultyEvaluator();

  final kept = <_Candidate>[];

  for (var i = 0; i < count; i++) {
    final seed = _seedAt(from + i);
    final level = generator.fromSeed(seed);
    if (level == null || !level.isStructurallyValid) continue;

    final solved = solver.solve(level);
    if (!solved.solvable) continue;

    // Filtres bon marché avant l'analyse fine, qui rejoue la partie.
    final exitable = LevelGenerator.exitableCount(level);
    final exitRatio = exitable / level.blocks.length;
    if (exitRatio > 0.75) continue;

    final board = quality.evaluate(level);
    if (board.score < 45) continue;

    // Le rapport coups / blocs se lit sur la solution. En dessous de 1,05, le
    // glissement ne sert à rien et le candidat ne dépassera jamais la première
    // tranche : inutile de payer l'analyse fine, qui rejoue toute la partie.
    if (solved.minimumMoves / level.blocks.length < 1.05) continue;

    final analysis = analyzer.analyse(level, solved);
    final score = difficulty.evaluate(level, solved, exitable);

    kept.add(_Candidate(
      seed: seed,
      blocks: level.blocks.length,
      stopTiles: level.stopTiles.length,
      gridSize: level.columns,
      optimalMoves: solved.minimumMoves,
      moveComplexity: analysis.moveComplexity,
      multiMoveRatio: analysis.multiMoveRatio,
      exitRatio: exitRatio,
      averageChoices: analysis.averageChoices,
      wrongMoves: analysis.wrongMoveOpportunities,
      deadEnds: analysis.deadEndOpportunities,
      narrowness: analysis.optimalPathNarrowness,
      decisionScore: analysis.decisionScore,
      difficultyScore: score.score,
      tier: score.tier,
      visualScore: board.score,
      fingerprint: LevelFingerprint.of(level),
      solution: solved.exampleSolution,
    ));
  }
  return kept;
}

/// Seeds bien écartées : deux indices voisins ne doivent pas donner des boards
/// voisins.
int _seedAt(int index) {
  var x = (index * 2654435761 + 1013904223) & 0xFFFFFFFF;
  x = ((x >> 16) ^ x) * 0x45d9f3b & 0xFFFFFFFF;
  x = ((x >> 16) ^ x) * 0x45d9f3b & 0xFFFFFFFF;
  return ((x >> 16) ^ x) & 0xFFFFFFFF;
}

/// Ce que le pool contient réellement : c'est lui qui borne la campagne.
void _poolProfile(List<_Candidate> pool) {
  final buckets = <String, int>{};
  for (final candidate in pool) {
    final key = switch (candidate.moveComplexity) {
      < 1.10 => '1.05-1.09',
      < 1.15 => '1.10-1.14',
      < 1.20 => '1.15-1.19',
      < 1.30 => '1.20-1.29',
      < 1.50 => '1.30-1.49',
      _ => '1.50+',
    };
    buckets[key] = (buckets[key] ?? 0) + 1;
  }
  final parts = [
    for (final key in [
      '1.05-1.09',
      '1.10-1.14',
      '1.15-1.19',
      '1.20-1.29',
      '1.30-1.49',
      '1.50+'
    ])
      '$key : ${buckets[key] ?? 0}',
  ];
  stdout.writeln('pool par complexité — ${parts.join('   ')}\n');
}

/// Répartit les candidats sur la campagne.
///
/// Chaque tranche a ses exigences ; à l'intérieur, les niveaux sont ordonnés du
/// plus doux au plus exigeant, pour que la montée se sente sans marche
/// d'escalier.
List<_Assignment> _select(List<_Candidate> pool, int levelCount) {
  final assignments = <_Assignment>[];
  final used = <String>{};

  // On sert les tranches les plus exigeantes en premier. À l'inverse, les
  // niveaux faciles rafleraient les meilleurs candidats au passage et la fin
  // de campagne se retrouverait avec les restes — c'est exactement ce qui
  // arrivait, la dernière tranche tombant sous le niveau des précédentes.
  final bands = [...difficultyBands]
    ..sort((a, b) => b.minDecisionScore.compareTo(a.minDecisionScore));

  for (final band in bands) {
    final start = _bandStart(band);
    final end = band.upToLevel.clamp(0, levelCount);

    for (var levelId = start; levelId <= end; levelId++) {
      final eligible = [
        for (final candidate in pool)
          if (!used.contains(candidate.fingerprint) && _fits(band, candidate))
            candidate,
      ];

      // Quand aucun candidat ne satisfait la tranche, on se rabat sur les
      // plus proches — mais seulement sur eux. Répartir sur tout le pool
      // reviendrait à servir des niveaux faciles dans la tranche difficile,
      // qui finissait ainsi plus douce que celle d'avant.
      final shortlist = eligible.isNotEmpty
          ? eligible
          : ([
              for (final candidate in pool)
                if (!used.contains(candidate.fingerprint)) candidate,
            ]..sort((a, b) => _distance(band, a).compareTo(_distance(band, b))))
              .take(_fallbackShortlist)
              .toList();

      if (shortlist.isEmpty) break;

      final chosen = _pickForPosition(shortlist, band, levelId, levelCount);
      used.add(chosen.fingerprint);
      assignments.add(_Assignment(levelId: levelId, candidate: chosen));
    }
  }

  assignments.sort((a, b) => a.levelId.compareTo(b.levelId));
  return assignments;
}

_Candidate _pickForPosition(
  List<_Candidate> shortlist,
  DifficultyBand band,
  int levelId,
  int levelCount,
) {
  final sorted = [...shortlist]
    ..sort((a, b) => a.decisionScore.compareTo(b.decisionScore));

  // La dernière tranche n'a pas de borne haute : sans ce plafond, la position
  // dans la tranche resterait proche de zéro et on y piocherait toujours les
  // candidats les plus faibles.
  final start = _bandStart(band);
  final end = band.upToLevel > levelCount ? levelCount : band.upToLevel;
  final span = (end - start + 1).clamp(1, 1 << 20);

  final progress = ((levelId - start) / span).clamp(0.0, 1.0);
  final index = (progress * (sorted.length - 1)).round();
  return sorted[index];
}

int _bandStart(DifficultyBand band) {
  var start = 1;
  for (final other in difficultyBands) {
    if (identical(other, band)) return start;
    start = other.upToLevel + 1;
  }
  return start;
}

bool _fits(DifficultyBand band, _Candidate candidate) =>
    candidate.moveComplexity >= band.minComplexity &&
    candidate.moveComplexity <= band.maxComplexity &&
    candidate.multiMoveRatio >= band.minMultiMoveRatio &&
    candidate.decisionScore >= band.minDecisionScore &&
    candidate.exitRatio <= band.maxExitRatio;

double _distance(DifficultyBand band, _Candidate candidate) {
  var distance = 0.0;
  if (candidate.moveComplexity < band.minComplexity) {
    distance += (band.minComplexity - candidate.moveComplexity) * 8;
  }
  if (candidate.moveComplexity > band.maxComplexity) {
    distance += (candidate.moveComplexity - band.maxComplexity) * 4;
  }
  if (candidate.multiMoveRatio < band.minMultiMoveRatio) {
    distance += (band.minMultiMoveRatio - candidate.multiMoveRatio) * 4;
  }
  if (candidate.decisionScore < band.minDecisionScore) {
    distance += (band.minDecisionScore - candidate.decisionScore) / 25;
  }
  if (candidate.exitRatio > band.maxExitRatio) {
    distance += (candidate.exitRatio - band.maxExitRatio) * 12;
  }
  return distance;
}

void _report(List<_Assignment> selection) {
  final byBand = <String, List<_Assignment>>{};
  for (final assignment in selection) {
    byBand
        .putIfAbsent(bandFor(assignment.levelId).name, () => [])
        .add(assignment);
  }

  stdout.writeln('tranche                niveaux  blocs  coups/bloc  rejoués'
      '  choix  erreurs  étroitesse  décision');
  for (final band in difficultyBands) {
    final rows = byBand[band.name];
    if (rows == null || rows.isEmpty) continue;
    double avg(double Function(_Candidate) field) =>
        rows.map((r) => field(r.candidate)).reduce((a, b) => a + b) /
        rows.length;

    stdout.writeln('${band.name.padRight(21)}'
        '  ${rows.length.toString().padLeft(7)}'
        '  ${avg((c) => c.blocks.toDouble()).toStringAsFixed(1).padLeft(5)}'
        '  ${avg((c) => c.moveComplexity).toStringAsFixed(2).padLeft(10)}'
        '  ${'${(avg((c) => c.multiMoveRatio) * 100).round()} %'.padLeft(7)}'
        '  ${avg((c) => c.averageChoices).toStringAsFixed(1).padLeft(5)}'
        '  ${avg((c) => c.wrongMoves.toDouble()).toStringAsFixed(1).padLeft(7)}'
        '  ${avg((c) => c.narrowness).toStringAsFixed(2).padLeft(10)}'
        '  ${avg((c) => c.decisionScore).toStringAsFixed(0).padLeft(8)}');
  }
}

Future<void> _export(List<_Assignment> selection) async {
  final levels = <CampaignLevel>[];
  final solutions = <Map<String, dynamic>>[];
  final report = <Map<String, dynamic>>[];


  for (final assignment in selection) {
    final candidate = assignment.candidate;
    levels.add(CampaignLevel(
      levelId: assignment.levelId,
      seed: candidate.seed,
      generatorVersion: currentGeneratorVersion,
      difficulty: candidate.tier,
      difficultyScore: candidate.difficultyScore,
      optimalMoves: candidate.optimalMoves,
      moveLimit:
          candidate.optimalMoves + moveAllowanceForLevel(assignment.levelId),
      fingerprint: candidate.fingerprint,
    ));

    solutions.add({
      'levelId': assignment.levelId,
      'seed': candidate.seed,
      'optimalMoves': candidate.optimalMoves,
      'solution': candidate.solution,
    });

    report.add({
      'levelId': assignment.levelId,
      'seed': candidate.seed,
      'handmade': false,
      'gridSize': candidate.gridSize,
      'blocks': candidate.blocks,
      'stopTiles': candidate.stopTiles,
      'optimalMoves': candidate.optimalMoves,
      'moveComplexity':
          double.parse(candidate.moveComplexity.toStringAsFixed(3)),
      'multiMoveRatio':
          double.parse(candidate.multiMoveRatio.toStringAsFixed(3)),
      'initialExitRatio': double.parse(candidate.exitRatio.toStringAsFixed(3)),
      'averageChoices':
          double.parse(candidate.averageChoices.toStringAsFixed(2)),
      'wrongMoveOpportunities': candidate.wrongMoves,
      'deadEndOpportunities': candidate.deadEnds,
      'optimalPathNarrowness':
          double.parse(candidate.narrowness.toStringAsFixed(3)),
      'decisionScore': double.parse(candidate.decisionScore.toStringAsFixed(1)),
      'visualScore': double.parse(candidate.visualScore.toStringAsFixed(1)),
    });
  }

  levels.sort((a, b) => a.levelId.compareTo(b.levelId));
  solutions.sort((a, b) => (a['levelId'] as int).compareTo(b['levelId'] as int));
  report.sort((a, b) => (a['levelId'] as int).compareTo(b['levelId'] as int));
  final campaign = Campaign(
    catalogVersion: catalogVersion,
    generatorVersion: currentGeneratorVersion,
    levels: levels,
  );

  const encoder = JsonEncoder.withIndent('  ');
  Directory('assets/levels').createSync(recursive: true);

  File('assets/levels/campaign_v$catalogVersion.json')
      .writeAsStringSync(encoder.convert(campaign.toJson()));
  File('assets/levels/campaign_v${catalogVersion}_solutions.json')
      .writeAsStringSync(encoder.convert({
    'catalogVersion': catalogVersion,
    'solutions': solutions,
  }));
  File('assets/levels/campaign_v${catalogVersion}_report.json')
      .writeAsStringSync(encoder.convert({
    'catalogVersion': catalogVersion,
    'levels': report,
  }));

  stdout.writeln('\n${levels.length} niveaux écrits dans assets/levels/');
}

class _Assignment {
  const _Assignment({required this.levelId, required this.candidate});
  final int levelId;
  final _Candidate candidate;
}

class _Candidate {
  const _Candidate({
    required this.seed,
    required this.blocks,
    required this.stopTiles,
    required this.gridSize,
    required this.optimalMoves,
    required this.moveComplexity,
    required this.multiMoveRatio,
    required this.exitRatio,
    required this.averageChoices,
    required this.wrongMoves,
    required this.deadEnds,
    required this.narrowness,
    required this.decisionScore,
    required this.difficultyScore,
    required this.tier,
    required this.visualScore,
    required this.fingerprint,
    required this.solution,
  });

  final int seed;
  final int blocks;
  final int stopTiles;
  final int gridSize;
  final int optimalMoves;
  final double moveComplexity;
  final double multiMoveRatio;
  final double exitRatio;
  final double averageChoices;
  final int wrongMoves;
  final int deadEnds;
  final double narrowness;
  final double decisionScore;
  final double difficultyScore;
  final Difficulty tier;
  final double visualScore;
  final String fingerprint;
  final List<String> solution;
}
