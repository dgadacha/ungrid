// Produit une campagne candidate dans build/campaign/, sans remplacer les
// associations niveau/seed déjà intégrées dans assets/levels/.
// dart compile exe tool/build_campaign.dart -o /tmp/ungrid-campaign
// /tmp/ungrid-campaign [nombre de seeds, 60000 par défaut]
// /tmp/ungrid-campaign --benchmark benchmark_stop_tiles.json
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:ungrid/game/campaign/campaign_level.dart';
import 'package:ungrid/game/campaign/campaign_profile.dart';
import 'package:ungrid/game/engine/generator_version.dart';
import 'package:ungrid/game/models/difficulty.dart';

import 'build_playtest.dart' show Candidate, evaluate;

Future<void> main(List<String> args) async {
  final fromBenchmark = args.length == 2 && args.first == '--benchmark';
  final count = fromBenchmark
      ? 60000
      : args.isEmpty
      ? 60000
      : int.parse(args.single);
  if (count < CampaignProfile.levelCount) {
    throw ArgumentError('Pool trop petit.');
  }
  final workers = math.min(8, Platform.numberOfProcessors);
  final seeds = fromBenchmark ? _benchmarkSeeds(args[1]) : null;
  stdout.writeln('$count seeds, $workers workers ; seuils stricts.');
  if (seeds != null) {
    stdout.writeln(
      '${seeds.length} seeds présélectionnées, reconstruction et analyse complètes.',
    );
  }
  final batches = await Future.wait([
    for (var w = 0; w < workers; w++)
      Isolate.run(
        () => seeds == null
            ? evaluate(w + 1, count, workers)
            : [
                for (var i = w; i < seeds.length; i += workers)
                  ...evaluate(seeds[i], seeds[i], 1),
              ],
      ),
  ]);
  final pool = batches.expand((batch) => batch).toList();
  stdout.writeln('${pool.length} candidats analysés complètement.');
  final ids = List.generate(CampaignProfile.levelCount, (i) => i + 1)
    ..sort((a, b) {
      final score = CampaignProfile.forLevel(
        b,
      ).targetScore.compareTo(CampaignProfile.forLevel(a).targetScore);
      return score != 0 ? score : a.compareTo(b);
    });
  final chosen = <int, Candidate>{};
  final used = <String>{};
  for (final id in ids) {
    final profile = CampaignProfile.forLevel(id);
    final eligible =
        pool
            .where(
              (c) =>
                  !used.contains(c.fingerprint) &&
                  profile.accepts(c.level, c.analysis),
            )
            .toList()
          ..sort((a, b) {
            final gap = (a.analysis.difficultyScore() - profile.targetScore)
                .abs()
                .compareTo(
                  (b.analysis.difficultyScore() - profile.targetScore).abs(),
                );
            return gap != 0 ? gap : a.seed.compareTo(b.seed);
          });
    if (eligible.isEmpty) {
      throw StateError(
        'Aucun candidat pour $id : augmenter le pool. Aucun repli facile.',
      );
    }
    chosen[id] = eligible.first;
    used.add(eligible.first.fingerprint);
  }
  final levels = <CampaignLevel>[];
  final reports = <Map<String, dynamic>>[];
  final solutions = <Map<String, dynamic>>[];
  for (var id = 1; id <= CampaignProfile.levelCount; id++) {
    final c = chosen[id]!;
    final score = c.analysis.difficultyScore();
    levels.add(
      CampaignLevel(
        levelId: id,
        seed: c.seed,
        generatorVersion: currentGeneratorVersion,
        difficulty: score < 70 ? Difficulty.hard : Difficulty.expert,
        difficultyScore: score,
        optimalMoves: c.solution.minimumMoves,
        fingerprint: c.fingerprint,
      ),
    );
    reports.add({
      'levelId': id,
      'seed': c.seed,
      'targetScore': CampaignProfile.forLevel(id).targetScore,
      'gridSize': c.level.columns,
      'visualScore': c.visualScore,
      ...c.analysis.toJson(),
    });
    solutions.add({'levelId': id, 'solution': c.solution.exampleSolution});
  }
  const encoder = JsonEncoder.withIndent('  ');
  Directory('build/campaign').createSync(recursive: true);
  void write(String suffix, Object value) => File(
    'build/campaign/campaign_v2$suffix.json',
  ).writeAsStringSync('${encoder.convert(value)}\n');
  write(
    '',
    Campaign(
      catalogVersion: 2,
      generatorVersion: currentGeneratorVersion,
      levels: levels,
    ).toJson(),
  );
  write('_report', {
    'candidateSeeds': count,
    if (fromBenchmark) 'prefilterSource': args[1],
    'eligibleCandidates': pool.length,
    'levels': reports,
  });
  write('_solutions', {'levels': solutions});
  stdout.writeln(
    '100 niveaux écrits ; scores ${levels.first.difficultyScore.toStringAsFixed(1)} → ${levels.last.difficultyScore.toStringAsFixed(1)}.',
  );
}

/// Les métriques arrondies du benchmark ne font qu'écarter les candidats
/// nettement hors cible. Le profil final est toujours vérifié sur une analyse
/// fraîche, et le mode sans cache reste disponible pour tout reconstruire.
List<int> _benchmarkSeeds(String path) {
  final data =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  if (data['generatorVersion'] != currentGeneratorVersion) {
    throw StateError('Benchmark d’une autre version du générateur.');
  }
  final fields = (data['fields'] as List).cast<String>();
  final selected = <int>{};
  for (final row in data['rows'] as List) {
    double value(String name) => (row[fields.indexOf(name)] as num).toDouble();
    if (value('group') != 1 ||
        value('difficultyScore') < 59.999 ||
        value('gridSize') > 6 ||
        value('blockCount') < 7 ||
        value('blockCount') > 14 ||
        value('stopTileCount') < 1 ||
        value('stopTileCount') > 2 ||
        value('visualScore') < 54.999 ||
        value('unresolvedAlternatives') != 0 ||
        value('unusedStopTileCount') != 0 ||
        value('trivialityPenalty') > 0.200001 ||
        value('optimalPathNarrowness') < 0.349999 ||
        value('temptingWrongMoveRatio') < 0.499999 ||
        value('dependencyComplexity') < 0.649999) {
      continue;
    }
    selected.add(value('seed').toInt());
  }
  return selected.toList()..sort();
}
