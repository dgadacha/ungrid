import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ungrid/app/theme.dart';
import 'package:ungrid/game/campaign/campaign_catalog.dart';
import 'package:ungrid/game/campaign/campaign_level.dart';
import 'package:ungrid/game/campaign/playtest_plan.dart';
import 'package:ungrid/game/engine/game_engine.dart';
import 'package:ungrid/game/engine/level_fingerprint.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/engine/puzzle_analysis.dart';
import 'package:ungrid/game/levels/level_repository.dart';
import 'package:ungrid/screens/playtest_screen.dart';
import 'package:ungrid/services/haptic_service.dart';
import 'package:ungrid/services/progress_service.dart';
import 'package:ungrid/widgets/game_board.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final campaign = Campaign.fromJson(
    jsonDecode(File(PlaytestPlan.assetPath).readAsStringSync())
        as Map<String, dynamic>,
  );
  final catalog = CampaignCatalog(campaign);
  final solutions =
      (jsonDecode(
                File(
                  'assets/levels/playtest_v1_solutions.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>)['levels']
          as List;

  test('vingt grilles distinctes, numérotées et reproductibles', () {
    expect(campaign.levelCount, 20);
    final fingerprints = <String>{};
    for (var id = 1; id <= 20; id++) {
      final definition = campaign[id]!;
      final level = catalog.levelFor(id)!;
      expect(level.isStructurallyValid, isTrue);
      expect(LevelFingerprint.of(level), definition.fingerprint);
      expect(fingerprints.add(definition.fingerprint), isTrue);
      expect(level.difficulty, definition.difficulty);
    }
  });

  for (var id = 1; id <= 20; id++) {
    test(
      'niveau $id : budget optimal, solution jouable et sélection vérifiée',
      () {
        final level = catalog.levelFor(id)!;
        final solved = const LevelSolver(maxExploredStates: 60000).solve(level);
        expect(solved.solvable, isTrue);
        expect(solved.minimumMoves, level.moveLimit);
        final engine = GameEngine(level);
        final solution = (solutions[id - 1] as Map)['solution'] as List;
        expect(solution.length, solved.minimumMoves);
        for (final blockId in solution.cast<String>()) {
          expect(engine.canMove(blockId), isTrue);
          engine.tap(blockId);
        }
        expect(engine.isCompleted, isTrue);

        final analysis = const PuzzleAnalyzer(
          solver: LevelSolver(maxExploredStates: 6000),
        ).analyse(level, solved);
        final stage = PlaytestPlan.stages[id - 1];
        expect(analysis.unresolvedAlternatives, 0);
        expect(analysis.unusedStopTileCount, 0);
        expect(
          analysis.trivialityPenalty,
          lessThanOrEqualTo(stage.maxTriviality),
        );
        expect(
          analysis.optimalPathNarrowness,
          greaterThanOrEqualTo(stage.minNarrowness),
        );
        expect(
          analysis.temptingWrongMoveRatio,
          greaterThanOrEqualTo(stage.minWrongRatio),
        );
        expect(
          analysis.dependencyComplexity,
          greaterThanOrEqualTo(stage.minDependency),
        );
        expect(analysis.difficultyScore(), closeTo(stage.targetScore, 4));
        expect(
          analysis.difficultyScore(),
          closeTo(campaign[id]!.difficultyScore, 0.01),
        );
      },
    );
  }

  test('les défis montent et les respirations sont plus douces', () {
    for (final id in [5, 10, 15]) {
      expect(
        campaign[id + 5]!.difficultyScore,
        greaterThan(campaign[id]!.difficultyScore),
      );
      expect(
        campaign[id + 1]!.difficultyScore,
        lessThan(campaign[id]!.difficultyScore),
      );
    }
    for (final id in [9, 14, 19]) {
      expect(
        campaign[id]!.difficultyScore,
        lessThan(campaign[id - 1]!.difficultyScore),
      );
    }
  });

  test('le lot fini ne fabrique pas un niveau 21', () async {
    final repository = LevelRepository(
      catalog: catalog,
      lastLevel: 20,
      useIsolate: false,
    );
    repository.prefetchAround(20);
    expect(await repository.levelFor(20), isNotNull);
    expect(() => repository.levelForSync(21), throwsRangeError);
    await expectLater(repository.levelFor(21), throwsRangeError);
  });

  testWidgets('le lot se charge depuis Playtest et borne la navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final progress = await ProgressService.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: UngridTheme.build(),
        home: PlaytestScreen(
          repository: LevelRepository(catalog: catalog, useIsolate: false),
          progress: progress,
          haptics: HapticService(enabled: false),
        ),
      ),
    );
    await tester.tap(find.text('20-LEVEL CHALLENGE'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 20'), findsOneWidget);
    await tester.tap(find.text('+10'));
    await tester.pump();
    expect(find.text('11 / 20'), findsOneWidget);
    await tester.tap(find.text('+10'));
    await tester.pump();
    expect(find.text('11 / 20'), findsOneWidget);
    await tester.tap(find.text('MASTERY · 16'));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('+1'));
      await tester.pump();
    }
    expect(find.text('20 / 20'), findsOneWidget);
    await tester.tap(find.text('PLAY LEVEL 20'));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<GameBoard>(find.byType(GameBoard))
        .controller;
    for (final id
        in ((solutions[19] as Map)['solution'] as List).cast<String>()) {
      final block = controller.engine.blockById(id)!;
      controller.tapCell(block.x, block.y);
    }
    expect(controller.isCleared, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('FINISH'), findsOneWidget);
    await tester.tap(find.text('FINISH'));
    await tester.pumpAndSettle();
    expect(find.text('20 / 20'), findsOneWidget);
    expect(progress.highestUnlockedLevel, 1);
    expect(progress.completedCount(), 0);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('ORIGINAL'));
    await tester.pump();
    expect(find.text('TIERS'), findsOneWidget);
    expect(find.text('CHAPTERS'), findsNothing);
    await tester.tap(find.text('ROTATION · 10'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 10'), findsOneWidget);
    await tester.tap(find.text('PLAY LEVEL 1'));
    await tester.pumpAndSettle();
    final rotation = tester
        .widget<GameBoard>(find.byType(GameBoard))
        .controller;
    expect(rotation.level.rotationTiles, isNotEmpty);
    expect(
      rotation.level.moveLimit,
      const LevelSolver().solve(rotation.level).minimumMoves,
    );
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Icon && w.icon == PhosphorIconsBold.arrowLeft,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('FRAGILE · 10'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 10'), findsOneWidget);
    await tester.tap(find.text('20-LEVEL CHALLENGE'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 20'), findsOneWidget);
    await tester.tap(find.text('FRAGILE · 10'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAY LEVEL 1'));
    await tester.pumpAndSettle();
    final fragile = tester.widget<GameBoard>(find.byType(GameBoard)).controller;
    expect(fragile.level.fragileStopTiles, isNotEmpty);
    expect(
      fragile.level.moveLimit,
      const LevelSolver().solve(fragile.level).minimumMoves,
    );
  });
}
