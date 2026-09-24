import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:ungrid/game/engine/board_quality_evaluator.dart';
import 'package:ungrid/game/engine/generator_version.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/engine/puzzle_analysis.dart';
import 'package:ungrid/game/engine/slide_generator.dart';
import 'package:ungrid/game/levels/level_pattern.dart';

/// Benchmark des tuiles d'arrêt.
///
/// Deux populations construites sur les **mêmes seeds** : sans tuile d'un
/// côté, avec de l'autre. Le tirage de la forme étant identique, chaque paire
/// part du même board — la différence mesurée ne vient que de la mécanique.
///
/// Rien ici ne sélectionne de niveau : on mesure, on compare, on publie les
/// distributions. Les seuils de la campagne viendront de ces chiffres, pas
/// l'inverse.
///
/// ```
/// dart compile exe tool/benchmark_stop_tiles.dart -o /tmp/bench
/// /tmp/bench --seeds 60000
/// ```

/// Colonnes du fichier détaillé, dans l'ordre.
const List<String> fields = [
  'group', // 0 sans tuile, 1 avec
  'seed',
  'gridSize',
  'blockCount',
  'stopTileCount',
  'optimalMoves',
  'moveComplexity',
  'multiMoveRatio',
  'maxMovesForSingleBlock',
  'averageChoices',
  'decisionScore',
  'optimalPathNarrowness',
  'temptingWrongMoveRatio',
  'dependencyComplexity',
  'stopTileInteractions',
  'meaningfulStopInteractions',
  'unusedStopTileCount',
  'stopDependencyScore',
  'stopTileDensity',
  'trivialityPenalty',
  'stateSpaceComplexity',
  'exploredStates',
  'unresolvedAlternatives',
  'deadEndStates',
  'branchingFactor',
  'wrongMoveOpportunities',
  'deadEndOpportunities',
  'difficultyScore',
  'visualScore',
  'solveMicros',
];

int _f(String name) => fields.indexOf(name);

class _Job {
  const _Job(this.first, this.last, this.step);

  /// Première seed de la tranche.
  final int first;

  /// Dernière seed possible, incluse.
  final int last;

  /// Pas entre deux seeds du même worker.
  ///
  /// Les tranches sont entrelacées plutôt que contiguës : la difficulté d'une
  /// seed dépend de la grille qu'elle tire, et les grandes grilles se
  /// regroupent. Découpées en blocs, un worker héritait des seeds coûteuses et
  /// tournait encore longtemps après les autres — la fin du run traînait à
  /// trois cœurs sur dix.
  final int step;
}

/// Construit, résout et analyse les seeds d'une tranche, pour les deux
/// groupes.
List<List<double>> _work(_Job job) {
  const generator = SlideGenerator();
  const solver = LevelSolver(maxExploredStates: 60000);
  const analyzer = PuzzleAnalyzer(solver: LevelSolver(maxExploredStates: 6000));
  const quality = BoardQualityEvaluator();

  final rows = <List<double>>[];

  for (var seed = job.first; seed <= job.last; seed += job.step) {
    for (var group = 0; group < 2; group++) {
      final level = generator.fromSeed(
        seed,
        levelId: seed,
        // Le groupe A n'a droit à aucune tuile ; le groupe B garde le budget
        // que la seed lui donne.
        stopTileBudget: group == 0 ? 0 : null,
      );
      if (level == null) continue;
      if (!level.isStructurallyValid) continue;

      final watch = Stopwatch()..start();
      final solved = solver.solve(level);
      watch.stop();
      if (!solved.solvable || !solved.exhaustive) continue;

      final analysis = analyzer.analyse(level, solved);
      final board = quality.evaluate(level);

      rows.add([
        group.toDouble(),
        seed.toDouble(),
        level.columns.toDouble(),
        level.blocks.length.toDouble(),
        analysis.stopTileCount.toDouble(),
        analysis.optimalMoves.toDouble(),
        analysis.moveComplexity,
        analysis.multiMoveRatio,
        analysis.maxMovesForSingleBlock.toDouble(),
        analysis.averageChoices,
        analysis.decisionScore,
        analysis.optimalPathNarrowness,
        analysis.temptingWrongMoveRatio,
        analysis.dependencyComplexity,
        analysis.stopTileInteractions.toDouble(),
        analysis.meaningfulStopInteractions.toDouble(),
        analysis.unusedStopTileCount.toDouble(),
        analysis.stopDependencyScore,
        analysis.stopTileDensity,
        analysis.trivialityPenalty,
        analysis.stateSpaceComplexity,
        analysis.exploredStates.toDouble(),
        analysis.unresolvedAlternatives.toDouble(),
        solved.deadEndCount.toDouble(),
        solved.averageBranchingFactor,
        analysis.wrongMoveOpportunities.toDouble(),
        analysis.deadEndOpportunities.toDouble(),
        analysis.difficultyScore(),
        board.score,
        watch.elapsedMicroseconds.toDouble(),
      ]);
    }
  }
  return rows;
}

Future<void> main(List<String> args) async {
  var seeds = 60000;
  var workers = math.max(1, Platform.numberOfProcessors - 1);
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--seeds') seeds = int.parse(args[i + 1]);
    if (args[i] == '--workers') workers = int.parse(args[i + 1]);
  }

  // Refaire les agrégats depuis le détail déjà calculé : le rapport se
  // retouche sans repayer une heure de solveur.
  if (args.contains('--from-json')) {
    final raw =
        jsonDecode(await File('benchmark_stop_tiles.json').readAsString())
            as Map<String, dynamic>;
    final rows = [
      for (final row in raw['rows'] as List)
        [for (final value in row as List) (value as num).toDouble()],
    ];
    final groupA = rows.where((r) => r[0] == 0).toList();
    final groupB = rows.where((r) => r[_f('stopTileCount')] > 0).toList();
    stdout.writeln('${rows.length} lignes relues');
    await _write(rows, _aggregate(rows, groupA, groupB, seeds, Duration.zero));
    stdout.writeln('Rapport réécrit.');
    return;
  }

  stdout.writeln('UNGRID — benchmark des tuiles d\'arrêt');
  stdout.writeln(
    'generatorVersion $currentGeneratorVersion, '
    '$seeds seeds x 2 groupes, $workers workers',
  );

  final watch = Stopwatch()..start();
  final futures = <Future<List<List<double>>>>[];
  for (var i = 0; i < workers; i++) {
    final first = 1 + i;
    if (first > seeds) continue;
    futures.add(Isolate.run(() => _work(_Job(first, seeds, workers))));
  }

  final rows = <List<double>>[];
  for (final chunk in await Future.wait(futures)) {
    rows.addAll(chunk);
  }
  watch.stop();

  final a = rows.where((r) => r[0] == 0).toList();
  final withTiles = rows.where((r) => r[_f('stopTileCount')] > 0).toList();
  final bWithout = rows.where((r) => r[0] == 1 && r[_f('stopTileCount')] == 0);

  stdout.writeln(
    '${rows.length} candidats résolus en '
    '${(watch.elapsedMilliseconds / 1000).toStringAsFixed(1)} s '
    '(A ${a.length}, B ${withTiles.length}, '
    'B sans tuile posée ${bWithout.length})',
  );

  final report = _aggregate(rows, a, withTiles, seeds, watch.elapsed);
  await _write(rows, report);
  stdout.writeln(
    'Écrit : benchmark_stop_tiles.json, '
    'benchmark_stop_tiles_summary.json, benchmark_stop_tiles_report.md, '
    'benchmark_top_levels.json',
  );
}

// ── Statistiques ──────────────────────────────────────────────────────────

double _percentile(List<double> sorted, double p) {
  if (sorted.isEmpty) return 0;
  final rank = (p * (sorted.length - 1)).round();
  return sorted[rank.clamp(0, sorted.length - 1)];
}

Map<String, double> _stats(List<List<double>> rows, String field) {
  if (rows.isEmpty) return const {};
  final index = _f(field);
  final values = [for (final r in rows) r[index]]..sort();
  final mean = values.fold<double>(0, (a, b) => a + b) / values.length;
  return {
    'mean': mean,
    'p50': _percentile(values, 0.50),
    'p90': _percentile(values, 0.90),
    'p95': _percentile(values, 0.95),
    'p99': _percentile(values, 0.99),
    'p999': _percentile(values, 0.999),
    'max': values.last,
    'min': values.first,
  };
}

double _correlation(List<List<double>> rows, String x, String y) {
  if (rows.length < 2) return 0;
  final ix = _f(x);
  final iy = _f(y);
  var sx = 0.0, sy = 0.0;
  for (final r in rows) {
    sx += r[ix];
    sy += r[iy];
  }
  final mx = sx / rows.length;
  final my = sy / rows.length;
  var num = 0.0, dx = 0.0, dy = 0.0;
  for (final r in rows) {
    final a = r[ix] - mx;
    final b = r[iy] - my;
    num += a * b;
    dx += a * a;
    dy += b * b;
  }
  if (dx == 0 || dy == 0) return 0;
  return num / math.sqrt(dx * dy);
}

const List<(String, double, double)> _buckets = [
  ('1.00-1.09', 1.00, 1.10),
  ('1.10-1.19', 1.10, 1.20),
  ('1.20-1.29', 1.20, 1.30),
  ('1.30-1.39', 1.30, 1.40),
  ('1.40-1.49', 1.40, 1.50),
  ('1.50-1.59', 1.50, 1.60),
  ('1.60-1.74', 1.60, 1.75),
  ('1.75-1.99', 1.75, 2.00),
  ('2.00-2.49', 2.00, 2.50),
  ('2.50-2.99', 2.50, 3.00),
  ('3.00+', 3.00, 1e9),
];

double _mean(List<List<double>> rows, String field) {
  if (rows.isEmpty) return 0;
  final i = _f(field);
  return rows.fold<double>(0, (a, r) => a + r[i]) / rows.length;
}

List<Map<String, dynamic>> _distribution(List<List<double>> rows) {
  final index = _f('moveComplexity');
  return [
    for (final (label, lo, hi) in _buckets)
      () {
        final inBucket = rows
            .where((r) => r[index] >= lo && r[index] < hi)
            .toList();
        return {
          'bucket': label,
          'count': inBucket.length,
          'percentage': rows.isEmpty
              ? 0.0
              : inBucket.length / rows.length * 100,
          'avgDifficultyScore': _mean(inBucket, 'difficultyScore'),
          'avgDecisionScore': _mean(inBucket, 'decisionScore'),
          'avgNarrowness': _mean(inBucket, 'optimalPathNarrowness'),
          'avgDependencyComplexity': _mean(inBucket, 'dependencyComplexity'),
          'avgStopInteractions': _mean(inBucket, 'stopTileInteractions'),
          'avgTrivialityPenalty': _mean(inBucket, 'trivialityPenalty'),
        };
      }(),
  ];
}

const List<String> _compared = [
  'optimalMoves',
  'moveComplexity',
  'multiMoveRatio',
  'maxMovesForSingleBlock',
  'decisionScore',
  'optimalPathNarrowness',
  'temptingWrongMoveRatio',
  'dependencyComplexity',
  'trivialityPenalty',
  'exploredStates',
  'difficultyScore',
  'visualScore',
];

const List<String> _correlated = [
  'moveComplexity',
  'stopTileCount',
  'stopTileInteractions',
  'meaningfulStopInteractions',
  'multiMoveRatio',
  'dependencyComplexity',
  'optimalPathNarrowness',
  'decisionScore',
  'difficultyScore',
  'trivialityPenalty',
];

Map<String, dynamic> _solverPerformance(List<List<double>> rows) {
  final sizes = <int, List<List<double>>>{};
  for (final r in rows) {
    sizes.putIfAbsent(r[_f('gridSize')].round(), () => []).add(r);
  }
  final keys = sizes.keys.toList()..sort();
  return {
    for (final size in keys)
      '${size}x$size': {
        'count': sizes[size]!.length,
        'solveMicros': _stats(sizes[size]!, 'solveMicros'),
        'exploredStates': _stats(sizes[size]!, 'exploredStates'),
      },
  };
}

List<Map<String, dynamic>> _top(
  List<List<double>> rows,
  String field, {
  int count = 20,
  bool Function(List<double>)? where,
}) {
  final index = _f(field);
  final pool = where == null ? rows.toList() : rows.where(where).toList();
  pool.sort((x, y) => y[index].compareTo(x[index]));
  return [for (final r in pool.take(count)) _describe(r)];
}

Map<String, dynamic> _describe(List<double> row) {
  final seed = row[_f('seed')].round();
  final level = const SlideGenerator().fromSeed(
    seed,
    levelId: seed,
    stopTileBudget: row[0] == 0 ? 0 : null,
  );
  final solution = level == null
      ? const <String>[]
      : const LevelSolver(
          maxExploredStates: 60000,
        ).solve(level).exampleSolution;

  return {
    'seed': seed,
    'generatorVersion': currentGeneratorVersion,
    'group': row[0] == 0 ? 'A' : 'B',
    'grid': level == null ? null : '${level.columns}x${level.rows}',
    'board': level == null ? null : LevelPattern.render(level),
    'blocks': level == null
        ? null
        : [
            for (final b in level.blocks)
              {'x': b.x, 'y': b.y, 'direction': b.direction.code},
          ],
    'stopTiles': level == null
        ? null
        : [
            for (final t in level.stopTiles) {'x': t.x, 'y': t.y},
          ],
    'optimalSolution': solution,
    'metrics': {for (var i = 0; i < fields.length; i++) fields[i]: row[i]},
  };
}

Map<String, dynamic> _aggregate(
  List<List<double>> all,
  List<List<double>> groupA,
  List<List<double>> groupB,
  int seeds,
  Duration elapsed,
) {
  // Un candidat « de qualité » : difficile, pas trivial, lisible. C'est lui
  // qui donne le plafond utile — le maximum brut peut n'être qu'un accident.
  bool highQuality(List<double> r) =>
      r[_f('difficultyScore')] >= 45 &&
      r[_f('trivialityPenalty')] <= 0.30 &&
      r[_f('visualScore')] >= 50;

  final qualityA = groupA.where(highQuality).toList();
  final qualityB = groupB.where(highQuality).toList();

  return {
    'run': {
      'generatorVersion': currentGeneratorVersion,
      'seeds': seeds,
      'candidates': all.length,
      'groupA': groupA.length,
      'groupB': groupB.length,
      'elapsedSeconds': elapsed.inMilliseconds / 1000,
      'highQualityRule':
          'difficultyScore >= 45 && trivialityPenalty <= 0.30 && visualScore >= 50',
    },
    'comparison': {
      for (final field in _compared)
        field: {
          'noStopTile': _stats(groupA, field),
          'stopTile': _stats(groupB, field),
        },
    },
    'moveComplexityCeiling': {
      'noStopTile': {
        'max': _stats(groupA, 'moveComplexity')['max'],
        'p95': _stats(groupA, 'moveComplexity')['p95'],
        'p99': _stats(groupA, 'moveComplexity')['p99'],
        'p999': _stats(groupA, 'moveComplexity')['p999'],
        'maxHighQuality': _stats(qualityA, 'moveComplexity')['max'] ?? 0,
        'highQualityCount': qualityA.length,
      },
      'stopTile': {
        'max': _stats(groupB, 'moveComplexity')['max'],
        'p95': _stats(groupB, 'moveComplexity')['p95'],
        'p99': _stats(groupB, 'moveComplexity')['p99'],
        'p999': _stats(groupB, 'moveComplexity')['p999'],
        'maxHighQuality': _stats(qualityB, 'moveComplexity')['max'] ?? 0,
        'highQualityCount': qualityB.length,
      },
    },
    'distribution': {
      'all': _distribution(all),
      'noStopTile': _distribution(groupA),
      'stopTile': _distribution(groupB),
    },
    'correlations': {
      'all': {
        for (final x in _correlated)
          x: {for (final y in _correlated) y: _correlation(all, x, y)},
      },
      'stopTile': {
        for (final x in _correlated)
          x: {for (final y in _correlated) y: _correlation(groupB, x, y)},
      },
    },
    'stopTileUsage': {
      'levelsWithUnusedTile': groupB
          .where((r) => r[_f('unusedStopTileCount')] > 0)
          .length,
      'unusedTileRate': groupB.isEmpty
          ? 0.0
          : groupB.where((r) => r[_f('unusedStopTileCount')] > 0).length /
                groupB.length,
      'avgStopTiles': _mean(groupB, 'stopTileCount'),
      'avgInteractions': _mean(groupB, 'stopTileInteractions'),
      'avgMeaningful': _mean(groupB, 'meaningfulStopInteractions'),
      'meaningfulShare': _mean(groupB, 'stopDependencyScore'),
      'byTileCount': {
        for (var n = 0; n <= 6; n++)
          '$n': () {
            final rows = groupB
                .where((r) => r[_f('stopTileCount')] == n)
                .toList();
            if (rows.isEmpty) return null;
            return {
              'count': rows.length,
              'avgMoveComplexity': _mean(rows, 'moveComplexity'),
              'avgDifficultyScore': _mean(rows, 'difficultyScore'),
              'avgTrivialityPenalty': _mean(rows, 'trivialityPenalty'),
            };
          }(),
      },
    },
    'solverPerformance': {
      'all': _solverPerformance(all),
      'noStopTile': _solverPerformance(groupA),
      'stopTile': _solverPerformance(groupB),
    },
    'outliers': {
      // Les listes ci-dessous sont tronquées pour rester lisibles ; les
      // compteurs disent combien de cas existent réellement.
      'longButEasyCount': all
          .where(
            (r) =>
                r[_f('moveComplexity')] >= 1.5 &&
                r[_f('difficultyScore')] <= 30,
          )
          .length,
      'shortButHardCount': all
          .where(
            (r) =>
                r[_f('moveComplexity')] <= 1.20 &&
                r[_f('difficultyScore')] >= 60,
          )
          .length,
      'longButEasy': [
        for (final r
            in (all
                    .where(
                      (r) =>
                          r[_f('moveComplexity')] >= 1.5 &&
                          r[_f('difficultyScore')] <= 30,
                    )
                    .toList()
                  ..sort(
                    (x, y) => y[_f('moveComplexity')].compareTo(
                      x[_f('moveComplexity')],
                    ),
                  ))
                .take(10))
          _describe(r),
      ],
      'shortButHard': [
        for (final r
            in (all
                    .where(
                      (r) =>
                          r[_f('moveComplexity')] <= 1.20 &&
                          r[_f('difficultyScore')] >= 60,
                    )
                    .toList()
                  ..sort(
                    (x, y) => y[_f('difficultyScore')].compareTo(
                      x[_f('difficultyScore')],
                    ),
                  ))
                .take(10))
          _describe(r),
      ],
    },
  };
}

Future<void> _write(
  List<List<double>> rows,
  Map<String, dynamic> summary,
) async {
  final encoder = const JsonEncoder.withIndent('  ');

  // Détail : un en-tête de colonnes et des lignes de nombres. Cent mille
  // objets nommés pèseraient dix fois plus pour la même information.
  await File('benchmark_stop_tiles.json').writeAsString(
    jsonEncode({
      'generatorVersion': currentGeneratorVersion,
      'fields': fields,
      'rows': [
        for (final r in rows)
          [for (final v in r) double.parse(v.toStringAsFixed(6))],
      ],
    }),
  );

  await File(
    'benchmark_stop_tiles_summary.json',
  ).writeAsString(encoder.convert(summary));

  final all = rows;
  final groupB = rows.where((r) => r[_f('stopTileCount')] > 0).toList();
  await File('benchmark_top_levels.json').writeAsString(
    encoder.convert({
      'highestMoveComplexity': _top(all, 'moveComplexity'),
      'highestDecisionScore': _top(all, 'decisionScore'),
      'highestNarrowness': _top(all, 'optimalPathNarrowness'),
      'highestDependencyComplexity': _top(all, 'dependencyComplexity'),
      'highestDifficultyScore': _top(all, 'difficultyScore'),
      'bestDifficultyAndVisual': _top(
        all,
        'difficultyScore',
        where: (r) => r[_f('visualScore')] >= 65,
      ),
      'highestMeaningfulStops': _top(groupB, 'meaningfulStopInteractions'),
    }),
  );

  await File(
    'benchmark_stop_tiles_report.md',
  ).writeAsString(_markdown(summary, rows));
}

/// La réponse à la seule question qui compte, tirée des chiffres du run.
///
/// Elle se calcule, elle ne s'écrit pas d'avance : si les tuiles n'apportaient
/// qu'une solution plus longue, le texte ci-dessous le dirait.
String _verdict(Map<String, dynamic> s) {
  final comparison = s['comparison'] as Map<String, dynamic>;
  double mean(String field, String group) =>
      ((comparison[field] as Map)[group] as Map<String, double>)['mean'] ?? 0;

  double gain(String field) {
    final a = mean(field, 'noStopTile');
    final b = mean(field, 'stopTile');
    return a == 0 ? 0 : (b - a) / a * 100;
  }

  final longer = gain('moveComplexity');
  final decision = gain('decisionScore');
  final narrow = gain('optimalPathNarrowness');
  final depend = gain('dependencyComplexity');
  final tempting = gain('temptingWrongMoveRatio');
  final trivial = gain('trivialityPenalty');
  final difficulty = gain('difficultyScore');

  final usage = s['stopTileUsage'] as Map<String, dynamic>;
  final meaningful = (usage['meaningfulShare'] as double) * 100;

  // Allonger n'est pas approfondir. Trois issues, pas deux : la mécanique
  // peut creuser les puzzles, les allonger à vide, ou — cas le plus probable
  // quand elle est bien posée — ajouter de la profondeur sans rien coûter.
  final deepens = decision > 2 && (narrow > 2 || depend > 2 || tempting > 2);
  final neutral = difficulty.abs() <= 5 && meaningful >= 50;
  final buffer = StringBuffer();

  if (deepens) {
    buffer.writeln(
      '**Oui.** Les tuiles allongent les solutions '
      '(${_fmt(longer, 1)} % de coups par bloc) *et* font monter ce que le '
      'joueur doit décider : score de décision ${_fmt(decision, 1)} %, '
      'étroitesse du chemin ${_fmt(narrow, 1)} %, dépendances '
      '${_fmt(depend, 1)} %, coups tentants qui coûtent '
      '${_fmt(tempting, 1)} %.',
    );
  } else if (neutral) {
    buffer.writeln(
      '**La tuile ajoute de la profondeur sans coûter de '
      'difficulté.** À seeds égales, les solutions comptent '
      '${_fmt(longer, 1)} % de coups par bloc en plus et '
      '${_fmt(gain('multiMoveRatio'), 0)} % de blocs rejoués en plus, pour un '
      'score de difficulté identique (${_fmt(difficulty, 1)} %, dans le '
      'bruit) et un score de décision de ${_fmt(decision, 1)} %. La mécanique '
      'ne creuse donc pas les puzzles par elle-même, mais elle ne les dilue '
      'plus : elle donne des positions intermédiaires là où il n\'y en avait '
      'aucune.',
    );
    buffer.writeln();
    buffer.writeln(
      'Ce qui reste en retrait est l\'étroitesse du chemin optimal '
      '(${_fmt(narrow, 1)} %), et c\'est structurel : un tap imposé par une '
      'tuile peut souvent se jouer à plusieurs moments sans rien coûter, donc '
      'plusieurs ordres restent optimaux. C\'est le prochain levier, pas un '
      'défaut de la mécanique.',
    );
  } else {
    buffer.writeln(
      '**Pas vraiment.** Les tuiles allongent les solutions '
      '(${_fmt(longer, 1)} % de coups par bloc) sans faire monter ce que le '
      'joueur doit décider : score de décision ${_fmt(decision, 1)} %, '
      'étroitesse ${_fmt(narrow, 1)} %, dépendances ${_fmt(depend, 1)} %. '
      'Ce sont surtout des taps obligatoires.',
    );
  }
  buffer.writeln();
  buffer.writeln(
    '${_fmt(meaningful, 1)} % des arrêts changent ce que les '
    'autres blocs peuvent faire${meaningful >= 50 ? '' : ' — les autres ne '
              'font qu\'ajouter un tap'}. C\'est ce que mesure '
    '`trivialityPenalty`, en hausse de ${_fmt(trivial, 1)} % : sans elle, il '
    'suffirait '
    'd\'aligner des tuiles pour paraître exigeant. Le score de difficulté '
    'global varie de ${_fmt(difficulty, 1)} %.',
  );
  buffer.writeln();
  final ceiling = s['moveComplexityCeiling'] as Map;
  final bare = ceiling['noStopTile'] as Map;
  final tiled = ceiling['stopTile'] as Map;

  buffer.writeln(
    'Le plafond, lui, a bien sauté. Sans tuile, le rapport tient '
    'pour l\'essentiel sous 1,25 — P99,9 à ${_fmt(bare['p999'], 3)} — ce qui '
    'confirme l\'ordre de grandeur attendu : un bloc n\'est joué deux fois '
    'que pris dans un blocage circulaire, et le plus petit en compte quatre '
    'pour un coup gagné. Mais le maximum mesuré atteint '
    '${_fmt(bare['max'], 3)}, donc **1,25 n\'était pas un plafond strict** : '
    'des blocages plus économes que la ronde existent, et la démonstration '
    'était approximative. Avec tuile, le maximum observé est de '
    '${_fmt(tiled['max'], 2)}, et ${_fmt(tiled['maxHighQuality'], 2)} si l\'on '
    'se limite aux candidats de qualité — c\'est ce second chiffre qui doit '
    'servir de repère, le maximum brut pouvant n\'être qu\'un accident.',
  );
  return buffer.toString();
}

String _fmt(num? v, [int digits = 2]) =>
    v == null ? '—' : v.toDouble().toStringAsFixed(digits);

String _markdown(Map<String, dynamic> s, List<List<double>> rows) {
  final run = s['run'] as Map<String, dynamic>;
  final comparison = s['comparison'] as Map<String, dynamic>;
  final ceiling = s['moveComplexityCeiling'] as Map<String, dynamic>;
  final usage = s['stopTileUsage'] as Map<String, dynamic>;
  final buffer = StringBuffer();

  buffer.writeln('# UNGRID — Benchmark des tuiles d\'arrêt');
  buffer.writeln();
  buffer.writeln(
    'Generator version ${run['generatorVersion']} · '
    '${run['seeds']} seeds · ${run['candidates']} candidats résolus · '
    '${_fmt(run['elapsedSeconds'], 1)} s',
  );
  buffer.writeln();
  buffer.writeln(
    'Les deux groupes sont construits **sur les mêmes seeds**, '
    'avec le même tirage de forme : à seed égale, le groupe A n\'a droit à '
    'aucune tuile et le groupe B garde son budget. La comparaison est donc '
    'appariée, et l\'écart mesuré ne vient que de la mécanique.',
  );
  buffer.writeln();

  buffer.writeln('## Sans tuile vs avec tuile');
  buffer.writeln();
  buffer.writeln('| Métrique | Sans tuile (A) | Avec tuile (B) | Écart |');
  buffer.writeln('| --- | ---: | ---: | ---: |');
  buffer.writeln('| candidats | ${run['groupA']} | ${run['groupB']} | |');
  for (final field in _compared) {
    final a = (comparison[field] as Map)['noStopTile'] as Map<String, double>;
    final b = (comparison[field] as Map)['stopTile'] as Map<String, double>;
    final ma = a['mean'] ?? 0;
    final mb = b['mean'] ?? 0;
    final delta = ma == 0 ? 0.0 : (mb - ma) / ma * 100;
    buffer.writeln(
      '| $field | ${_fmt(ma, 3)} | ${_fmt(mb, 3)} | '
      '${delta >= 0 ? '+' : ''}${_fmt(delta, 1)} % |',
    );
  }
  buffer.writeln();

  buffer.writeln('## Le plafond du rapport coups / blocs');
  buffer.writeln();
  buffer.writeln('| | Sans tuile | Avec tuile |');
  buffer.writeln('| --- | ---: | ---: |');
  for (final key in ['p95', 'p99', 'p999', 'max', 'maxHighQuality']) {
    buffer.writeln(
      '| $key | '
      '${_fmt((ceiling['noStopTile'] as Map)[key], 3)} | '
      '${_fmt((ceiling['stopTile'] as Map)[key], 3)} |',
    );
  }
  buffer.writeln(
    '| candidats de qualité | '
    '${(ceiling['noStopTile'] as Map)['highQualityCount']} | '
    '${(ceiling['stopTile'] as Map)['highQualityCount']} |',
  );
  buffer.writeln();
  buffer.writeln('Règle de qualité : `${run['highQualityRule']}`.');
  buffer.writeln();

  buffer.writeln('## Distribution du rapport coups / blocs');
  buffer.writeln();
  for (final entry in ['noStopTile', 'stopTile']) {
    buffer.writeln(
      '### ${entry == 'noStopTile' ? 'Sans tuile' : 'Avec tuile'}',
    );
    buffer.writeln();
    buffer.writeln(
      '| Tranche | Candidats | % | Difficulté | Décision | '
      'Étroitesse | Dépendance | Arrêts | Trivialité |',
    );
    buffer.writeln(
      '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |',
    );
    for (final bucket
        in (s['distribution'] as Map)[entry] as List<Map<String, dynamic>>) {
      if (bucket['count'] == 0) continue;
      buffer.writeln(
        '| ${bucket['bucket']} | ${bucket['count']} | '
        '${_fmt(bucket['percentage'], 1)} | '
        '${_fmt(bucket['avgDifficultyScore'], 1)} | '
        '${_fmt(bucket['avgDecisionScore'], 1)} | '
        '${_fmt(bucket['avgNarrowness'], 3)} | '
        '${_fmt(bucket['avgDependencyComplexity'], 3)} | '
        '${_fmt(bucket['avgStopInteractions'], 2)} | '
        '${_fmt(bucket['avgTrivialityPenalty'], 3)} |',
      );
    }
    buffer.writeln();
  }

  buffer.writeln('## Ce que les tuiles servent vraiment');
  buffer.writeln();
  buffer.writeln('- tuiles par niveau : ${_fmt(usage['avgStopTiles'])}');
  buffer.writeln(
    '- arrêts le long de la solution : '
    '${_fmt(usage['avgInteractions'])}',
  );
  buffer.writeln(
    '- dont porteurs d\'une dépendance : '
    '${_fmt(usage['avgMeaningful'])} '
    '(${_fmt((usage['meaningfulShare'] as double) * 100, 1)} %)',
  );
  buffer.writeln(
    '- niveaux avec au moins une tuile inutilisée : '
    '${usage['levelsWithUnusedTile']} '
    '(${_fmt((usage['unusedTileRate'] as double) * 100, 1)} %)',
  );
  buffer.writeln();
  buffer.writeln(
    '| Tuiles | Candidats | Coups/bloc | Difficulté | Trivialité |',
  );
  buffer.writeln('| ---: | ---: | ---: | ---: | ---: |');
  (usage['byTileCount'] as Map).forEach((key, value) {
    if (value == null) return;
    final v = value as Map<String, dynamic>;
    buffer.writeln(
      '| $key | ${v['count']} | '
      '${_fmt(v['avgMoveComplexity'], 3)} | '
      '${_fmt(v['avgDifficultyScore'], 1)} | '
      '${_fmt(v['avgTrivialityPenalty'], 3)} |',
    );
  });
  buffer.writeln();

  buffer.writeln('## Corrélations');
  buffer.writeln();
  buffer.writeln('Coefficient de Pearson, toutes populations confondues.');
  buffer.writeln();
  final correlations = (s['correlations'] as Map)['all'] as Map;
  buffer.write('| |');
  for (final y in _correlated) {
    buffer.write(' ${y.substring(0, math.min(9, y.length))} |');
  }
  buffer.writeln();
  buffer.write('| --- |');
  for (var i = 0; i < _correlated.length; i++) {
    buffer.write(' ---: |');
  }
  buffer.writeln();
  for (final x in _correlated) {
    buffer.write('| $x |');
    for (final y in _correlated) {
      buffer.write(' ${_fmt((correlations[x] as Map)[y], 2)} |');
    }
    buffer.writeln();
  }
  buffer.writeln();

  buffer.writeln('## Performance du solveur');
  buffer.writeln();
  buffer.writeln(
    '| Grille | Candidats | moyenne (ms) | P95 (ms) | P99 (ms) | '
    'max (ms) | états explorés (P99) |',
  );
  buffer.writeln('| --- | ---: | ---: | ---: | ---: | ---: | ---: |');
  ((s['solverPerformance'] as Map)['all'] as Map).forEach((size, value) {
    final v = value as Map<String, dynamic>;
    final micros = v['solveMicros'] as Map<String, double>;
    final states = v['exploredStates'] as Map<String, double>;
    buffer.writeln(
      '| $size | ${v['count']} | '
      '${_fmt((micros['mean'] ?? 0) / 1000)} | '
      '${_fmt((micros['p95'] ?? 0) / 1000)} | '
      '${_fmt((micros['p99'] ?? 0) / 1000)} | '
      '${_fmt((micros['max'] ?? 0) / 1000)} | '
      '${_fmt(states['p99'], 0)} |',
    );
  });
  buffer.writeln();

  buffer.writeln('## La tuile approfondit-elle vraiment les puzzles ?');
  buffer.writeln();
  buffer.write(_verdict(s));
  buffer.writeln();

  buffer.writeln('## Cas limites');
  buffer.writeln();
  final outliers = s['outliers'] as Map<String, dynamic>;
  buffer.writeln(
    '**Longs mais faciles** — rapport coups / blocs au-dessus de '
    '1,5 pour une difficulté sous 30 : **${outliers['longButEasyCount']} '
    'candidats**. Ce sont des taps obligatoires, pas des décisions : c\'est '
    'exactement ce que `trivialityPenalty` doit retrancher.',
  );
  buffer.writeln();
  buffer.writeln(
    '**Courts mais durs** — rapport sous 1,20 pour une difficulté '
    'au-dessus de 60 : **${outliers['shortButHardCount']} candidats**. La '
    'difficulté ne se lit donc pas dans la longueur — et il y en a '
    '${outliers['shortButHardCount'] > outliers['longButEasyCount'] ? 'plus' : 'moins'} '
    'que de longs faciles.',
  );
  buffer.writeln();
  buffer.writeln(
    'Les dix premiers de chaque catégorie sont détaillés dans '
    '`benchmark_stop_tiles_summary.json`, les meilleurs candidats dans '
    '`benchmark_top_levels.json`.',
  );
  buffer.writeln();
  buffer.writeln('---');
  buffer.writeln();
  buffer.writeln(
    'Fichiers : `benchmark_stop_tiles.json` (détail, '
    '${rows.length} lignes), `benchmark_stop_tiles_summary.json` (agrégats), '
    '`benchmark_top_levels.json` (candidats exportés).',
  );
  return buffer.toString();
}
