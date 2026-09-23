import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ungrid/game/campaign/campaign_catalog.dart';
import 'package:ungrid/game/campaign/campaign_level.dart';
import 'package:ungrid/game/engine/game_engine.dart';
import 'package:ungrid/game/engine/level_fingerprint.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/engine/puzzle_analysis.dart';
import 'package:ungrid/game/levels/level_repository.dart';
import 'package:ungrid/game/models/grid_position.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('une grille publiée altérée est rejetée au chargement', () async {
    final catalog = await CampaignCatalog.load();
    final raw = catalog.campaign.toJson();
    final first = (raw['levels'] as List).first as Map<String, dynamic>;
    first['fingerprint'] = 'invalid';
    final corrupt = CampaignCatalog(Campaign.fromJson(raw));
    expect(() => corrupt.levelFor(1), throwsStateError);
  });
  test(
    'campagne active : 100 rotations distinctes, utiles et optimales',
    () async {
      final catalog = await CampaignCatalog.load();
      expect(catalog.campaign.catalogVersion, 3);
      expect(catalog.levelCount, 100);
      final report =
          jsonDecode(
                File(
                  'assets/levels/campaign_v3_solutions.json',
                ).readAsStringSync(),
              )
              as Map;
      final seen = <String>{};
      double previous = 0;
      for (var id = 1; id <= 100; id++) {
        final level = catalog.levelFor(id)!;
        expect(level.id, id);
        expect(level.rotationTiles, isNotEmpty);
        expect(seen.add(LevelFingerprint.of(level)), isTrue);
        expect(level.blocks.length, inInclusiveRange(7, 12));
        final result = const LevelSolver().solve(level);
        expect(result.solvable, isTrue, reason: 'niveau $id');
        expect(result.exhaustive, isTrue);
        expect(result.minimumMoves, level.moveLimit);
        final analysis = const PuzzleAnalyzer(
          solver: LevelSolver(maxExploredStates: 6000),
        ).analyse(level, result);
        expect(analysis.unresolvedAlternatives, 0);
        expect(analysis.unusedStopTileCount, 0);
        expect(analysis.difficultyScore(), greaterThanOrEqualTo(60));
        expect(analysis.trivialityPenalty, lessThanOrEqualTo(.2));
        expect(analysis.optimalPathNarrowness, greaterThanOrEqualTo(.35));
        expect(analysis.temptingWrongMoveRatio, greaterThanOrEqualTo(.5));
        expect(analysis.dependencyComplexity, greaterThanOrEqualTo(.65));
        final score = catalog.definitionFor(id)!.difficultyScore;
        expect(score, greaterThanOrEqualTo(previous));
        previous = score;
        final engine = GameEngine(level);
        final plain = GameEngine(
          level.copyWith(rotationTiles: [], stopTiles: level.rotationTiles),
        );
        final visited = <GridPosition>{};
        final moves = (report['levels'][id - 1]['solution'] as List)
            .cast<String>();
        expect(moves.length, level.moveLimit);
        for (final move in moves) {
          expect(engine.canMove(move), isTrue);
          final landed = engine.tap(move).to;
          if (level.rotationTiles.contains(landed)) visited.add(landed!);
          plain.tap(move);
        }
        expect(engine.isCompleted, isTrue);
        expect(plain.isCompleted, isFalse);
        expect(visited.length, level.rotationTiles.length);
      }
      expect(
        catalog.definitionFor(100)!.difficultyScore,
        greaterThan(catalog.definitionFor(1)!.difficultyScore),
      );
      final repository = LevelRepository(catalog: catalog, lastLevel: 100);
      expect(repository.levelForSync(100).rotationTiles, isNotEmpty);
      expect(() => repository.levelForSync(101), throwsRangeError);
      final restored = CampaignCatalog(
        Campaign.fromJson(catalog.campaign.toJson()),
      );
      expect(
        LevelFingerprint.of(restored.levelFor(100)!),
        LevelFingerprint.of(catalog.levelFor(100)!),
      );
    },
  );
}
