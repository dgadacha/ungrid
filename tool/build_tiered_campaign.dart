// Campagne v5 : quatre paliers au lieu d'un seul profil.
//
// La v4 ne contenait que des niveaux du palier le plus dur : son profil
// exigeait sept blocs et un score de soixante partout, si bien que le premier
// niveau demandait déjà seize coups. On garde ce lot pour la fin de campagne
// — il est validé, ses solutions sont publiées — et on construit devant lui
// la montée qui manquait.
import 'dart:convert';
import 'dart:io';

import 'package:ungrid/game/campaign/campaign_profile.dart';
import 'package:ungrid/game/engine/level_fingerprint.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/engine/planning_difficulty.dart';
import 'package:ungrid/game/engine/puzzle_analysis.dart';
import 'package:ungrid/game/engine/rotation_generator.dart';
import 'package:ungrid/game/models/level.dart';

class _Candidate {
  _Candidate(this.level, this.analysis, this.planning, this.solution);
  final Level level;
  final PuzzleAnalysis analysis;
  final PlanningDifficulty planning;
  final List<String> solution;

  double get score => analysis.difficultyScore();
}

void main(List<String> args) {
  final seeds = args.isEmpty ? 60000 : int.parse(args.first);
  const solver = LevelSolver(maxExploredStates: 40000);
  const analyzer = PuzzleAnalyzer(solver: LevelSolver(maxExploredStates: 4000));
  const generator = RotationGenerator(maxBlocks: 13, maxRotationTiles: 3);

  final pools = <CampaignTier, List<_Candidate>>{
    for (final tier in CampaignTier.values) tier: [],
  };
  final seen = <String>{};

  stdout.writeln('Recherche sur $seeds seeds...');
  for (var seed = 1; seed <= seeds; seed++) {
    if (seed % 10000 == 0) {
      stdout.writeln('  seed $seed : '
          '${pools.entries.map((e) => '${e.key.name} ${e.value.length}').join(', ')}');
    }
    final level = generator.fromSeed(seed, levelId: seed);
    if (level == null) continue;
    final solved = solver.solve(level);
    if (!solved.solvable || !solved.exhaustive) continue;

    final ready = level.copyWith(optimalMoves: solved.minimumMoves);
    if (!seen.add(LevelFingerprint.of(ready))) continue;

    final analysis = analyzer.analyse(ready, solved);
    final planning =
        PlanningDifficulty.measure(ready, solved.exampleSolution);

    for (final tier in CampaignTier.values) {
      // Le dernier palier vient de la v4 : inutile d'en chercher ici.
      if (tier == CampaignTier.extreme) continue;
      if (tier.accepts(ready, analysis, planning)) {
        pools[tier]!.add(
          _Candidate(ready, analysis, planning, solved.exampleSolution),
        );
        break;
      }
    }
  }

  // Le palier final reprend la v4, déjà validée, du plus doux au plus dur.
  final v4 = jsonDecode(
    File('assets/levels/campaign_v4.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final v4Solutions = jsonDecode(
    File('assets/levels/campaign_v4_solutions.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  // Les solutions v4 sont rangées par identifiant de niveau, sous la clé
  // « id » — le fichier porte le board complet, pas seulement la suite de
  // coups.
  final solutionsById = {
    for (final raw in v4Solutions['levels'] as List)
      (raw as Map)['id'] as int: (raw['solution'] as List).cast<String>(),
  };
  final extreme = <_Candidate>[];
  for (final raw in v4['levels'] as List) {
    final definition = raw as Map<String, dynamic>;
    final level = Level.fromJson(definition['board'] as Map<String, dynamic>)
        .copyWith(optimalMoves: definition['optimalMoves'] as int);
    final solved = solver.solve(level);
    if (!solved.solvable) continue;
    extreme.add(_Candidate(
      level,
      analyzer.analyse(level, solved),
      PlanningDifficulty.measure(level, solved.exampleSolution),
      solutionsById[definition['levelId'] as int] ?? solved.exampleSolution,
    ));
  }
  extreme.sort((a, b) => a.score.compareTo(b.score));
  pools[CampaignTier.extreme] = extreme;

  stdout.writeln('\nRéservoir :');
  for (final tier in CampaignTier.values) {
    stdout.writeln('  ${tier.name.padRight(10)} ${pools[tier]!.length} '
        '(${tier.levelCount} requis)');
  }

  final selection = <_Candidate>[];
  for (final tier in CampaignTier.values) {
    final pool = pools[tier]!..sort((a, b) => a.score.compareTo(b.score));
    if (pool.length < tier.levelCount) {
      stderr.writeln('Palier ${tier.name} : '
          '${pool.length} candidats pour ${tier.levelCount} niveaux.');
      exit(1);
    }
    // Un échantillon régulier du réservoir trié : la difficulté monte à
    // l'intérieur du palier sans se cantonner aux extrêmes.
    final step = pool.length / tier.levelCount;
    for (var i = 0; i < tier.levelCount; i++) {
      selection.add(pool[(i * step).floor()]);
    }
  }

  final levels = <Map<String, dynamic>>[];
  final solutions = <Map<String, dynamic>>[];
  for (var i = 0; i < selection.length; i++) {
    final id = i + 1;
    final candidate = selection[i];
    final level = candidate.level.copyWith(id: id);
    levels.add({
      'levelId': id,
      'seed': level.seed ?? 0,
      'generatorVersion': 5,
      'difficulty': level.difficulty.name,
      'difficultyScore': candidate.score,
      'optimalMoves': level.optimalMoves,
      'status': 'active',
      'fingerprint': LevelFingerprint.of(level),
      'board': level.toJson(),
      'tier': CampaignTier.forLevel(id).name,
      'planning': candidate.planning.toJson(),
    });
    solutions.add({
      'levelId': id,
      'solution': candidate.solution,
      'metrics': candidate.analysis.toJson(),
    });
  }

  const encoder = JsonEncoder.withIndent('  ');
  File('assets/levels/campaign_v5.json').writeAsStringSync(
    '${encoder.convert({
      'catalogVersion': 5,
      'generatorVersion': 5,
      'levelCount': levels.length,
      'mechanic': 'rotation-tiered-v1',
      'levels': levels,
    })}\n',
  );
  File('assets/levels/campaign_v5_solutions.json').writeAsStringSync(
    '${encoder.convert({'levels': solutions})}\n',
  );

  stdout.writeln('\nCampagne écrite : ${levels.length} niveaux');
  for (final tier in CampaignTier.values) {
    final ids = [
      for (var id = 1; id <= levels.length; id++)
        if (CampaignTier.forLevel(id) == tier) id,
    ];
    final first = levels[ids.first - 1];
    final last = levels[ids.last - 1];
    stdout.writeln('  ${tier.name.padRight(10)} niveaux ${ids.first}-${ids.last} : '
        '${first['optimalMoves']} à ${last['optimalMoves']} coups, '
        'score ${(first['difficultyScore'] as double).toStringAsFixed(0)}'
        ' à ${(last['difficultyScore'] as double).toStringAsFixed(0)}');
  }
}
