@Timeout(Duration(minutes: 10))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ungrid/game/engine/level_generator.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/levels/level_pattern.dart';
import 'package:ungrid/game/levels/manual_levels.dart';
import 'package:ungrid/game/models/level.dart';

/// Épreuve de fond : mille niveaux d'affilée.
///
/// C'est le test qui décide si le générateur est utilisable. Il vérifie qu'on
/// peut jouer mille niveaux sans en croiser un seul de cassé, que la
/// difficulté monte vraiment, et que rien ne prend assez de temps pour se voir.
void main() {
  const generator = LevelGenerator();
  const solver = LevelSolver();
  const total = 1000;

  late List<_Sample> samples;

  setUpAll(() {
    samples = [];
    for (var id = 1; id <= total; id++) {
      final watch = Stopwatch()..start();

      if (ManualLevels.contains(id)) {
        final level = ManualLevels.byId(id);
        watch.stop();
        samples.add(_Sample(
          id: id,
          level: level,
          micros: watch.elapsedMicroseconds,
          solvable: solver.solve(level).solvable,
          moves: level.optimalMoves,
        ));
      } else {
        final generated = generator.generate(levelId: id);
        watch.stop();
        samples.add(_Sample(
          id: id,
          level: generated.level,
          micros: watch.elapsedMicroseconds,
          solvable: generated.solveResult.solvable,
          moves: generated.solveResult.minimumMoves,
          score: generated.difficulty.score,
          exitableRatio: generated.difficulty.exitableRatio,
        ));
      }
    }
  });

  test('les mille niveaux sont structurellement valides', () {
    for (final sample in samples) {
      final trace = LevelPattern.render(sample.level).join('\n');
      expect(sample.level.blocks, isNotEmpty,
          reason: 'niveau ${sample.id} vide');
      expect(sample.level.isStructurallyValid, isTrue,
          reason: 'niveau ${sample.id} : coordonnées ou doublons\n$trace');
      expect(sample.level.occupancy, lessThan(0.75),
          reason: 'niveau ${sample.id} : plus rien ne peut glisser\n$trace');
    }
  });

  test('les mille niveaux se terminent', () {
    final broken = samples.where((s) => !s.solvable).map((s) => s.id).toList();
    expect(broken, isEmpty, reason: 'niveaux insolubles : $broken');
  });

  test('la limite de coups est la solution optimale', () {
    for (final sample in samples) {
      expect(sample.level.moveLimit, sample.moves,
          reason: 'niveau ${sample.id} : la limite doit valoir l\'optimal');
    }
  });

  test('un même numéro donne toujours le même board', () {
    for (final id in [7, 21, 128, 349, 512, 777, 1000]) {
      final a = ManualLevels.contains(id)
          ? ManualLevels.byId(id)
          : generator.generate(levelId: id).level;
      final b = ManualLevels.contains(id)
          ? ManualLevels.byId(id)
          : generator.generate(levelId: id).level;
      expect(LevelPattern.render(a), LevelPattern.render(b),
          reason: 'niveau $id non reproductible');
    }
  });

  test('la difficulté monte au fil des niveaux', () {
    double average(int from, int to, double? Function(_Sample) field) {
      final values = samples
          .where((s) => s.id >= from && s.id <= to)
          .map(field)
          .whereType<double>()
          .toList();
      return values.reduce((a, b) => a + b) / values.length;
    }

    final blocksEarly =
        average(21, 120, (s) => s.level.blocks.length.toDouble());
    final blocksLate =
        average(400, 500, (s) => s.level.blocks.length.toDouble());
    final scoreEarly = average(21, 120, (s) => s.score);
    final scoreLate = average(400, 500, (s) => s.score);

    expect(blocksLate, greaterThan(blocksEarly));
    expect(scoreLate, greaterThan(scoreEarly));
  });

  test('les boards ne tombent pas tous dans le même moule', () {
    // La construction est très contrainte : deux niveaux d'une même tranche
    // finissent parfois sur le même board. Ce qui compte, c'est que le joueur
    // ne s'en aperçoive pas — donc jamais deux niveaux proches.
    final seenAt = <String, int>{};
    final duplicates = <int>[];
    final nearDuplicates = <String>[];

    for (final sample in samples.where((s) => s.id > 20)) {
      final signature = LevelPattern.render(sample.level).join('/');
      final previous = seenAt[signature];
      if (previous == null) {
        seenAt[signature] = sample.id;
        continue;
      }
      duplicates.add(sample.id);
      if (sample.id - previous < 10) {
        nearDuplicates.add('$previous et ${sample.id}');
      }
    }

    expect(nearDuplicates, isEmpty,
        reason: 'boards identiques à portée de mémoire : $nearDuplicates');
    expect(duplicates.length / samples.length, lessThan(0.01),
        reason: 'trop de boards identiques : ${duplicates.length}');

    final counts = <String, int>{};
    for (final sample in samples) {
      for (final block in sample.level.blocks) {
        counts[block.direction.code] = (counts[block.direction.code] ?? 0) + 1;
      }
    }
    final totalBlocks = counts.values.reduce((a, b) => a + b);
    for (final entry in counts.entries) {
      expect(entry.value / totalBlocks, lessThan(0.35),
          reason: 'direction ${entry.key} sur-représentée');
    }
  });

  test('la génération reste imperceptible', () {
    final durations = samples.map((s) => s.micros).toList()..sort();
    final median = durations[durations.length ~/ 2] / 1000;
    final p95 = durations[(durations.length * 0.95).floor()] / 1000;
    final worst = durations.last / 1000;

    // Mesure pessimiste : la machine de test tourne en mode debug, assertions
    // comprises. Compilé en natif, comme sur un téléphone, le même travail est
    // plusieurs fois plus rapide (voir tool/analyze_generated.dart). Ces
    // bornes servent à repérer une régression, pas à fixer le budget réel.
    expect(median, lessThan(500), reason: 'médiane ${median}ms');
    expect(p95, lessThan(2500), reason: 'p95 ${p95}ms');
    expect(worst, lessThan(6000), reason: 'pire cas ${worst}ms');
  });
}

class _Sample {
  const _Sample({
    required this.id,
    required this.level,
    required this.micros,
    required this.solvable,
    required this.moves,
    this.score,
    this.exitableRatio,
  });

  final int id;
  final Level level;
  final int micros;
  final bool solvable;
  final int moves;
  final double? score;
  final double? exitableRatio;
}
