import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ungrid/app/theme.dart';
import 'package:ungrid/game/levels/level_pattern.dart';
import 'package:ungrid/game/levels/level_repository.dart';
import 'package:ungrid/screens/game_screen.dart';
import 'package:ungrid/services/haptic_service.dart';
import 'package:ungrid/services/progress_service.dart';
import 'package:ungrid/widgets/game_board.dart';

/// Laisse passer l'ouverture ou la fermeture de la modale.
///
/// `pumpAndSettle` ne convient pas ici : la partie anime en continu, il n'y a
/// donc jamais de frame au repos à attendre.
Future<void> settleDialog(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('la deuxième annulation demande avant de dépenser', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final progress = await ProgressService.load();

    // Deux blocs face à face : le coup glisse sans vider la grille, donc
    // l'annulation reste possible d'un bout à l'autre du test.
    final level = LevelPattern.parse([
      '....',
      '>..<',
      '....',
      '....',
    ], id: 1).copyWith(optimalMoves: 6);

    await tester.pumpWidget(
      MaterialApp(
        theme: UngridTheme.build(),
        home: GameScreen(
          levelId: 1,
          repository: LevelRepository(fixedLevels: [level], lastLevel: 1),
          progress: progress,
          haptics: HapticService(enabled: false),
        ),
      ),
    );
    await settleDialog(tester);
    final controller = tester
        .widget<GameBoard>(find.byType(GameBoard))
        .controller;

    // La première annulation est offerte : rien n'est demandé.
    controller.tapCell(0, 1);
    await settleDialog(tester);
    await tester.tap(find.text('UNDO'));
    await settleDialog(tester);
    expect(find.text('One more undo?'), findsNothing);
    expect(controller.movesUsed, 0);

    // La deuxième passe par la modale, et refuser ne coûte rien.
    controller.tapCell(0, 1);
    await settleDialog(tester);
    await tester.tap(find.text('UNDO'));
    await settleDialog(tester);
    expect(find.text('One more undo?'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await settleDialog(tester);
    expect(controller.movesUsed, 1);

    // Accepter la vidéo rend le coup.
    await tester.tap(find.text('UNDO'));
    await settleDialog(tester);
    await tester.tap(find.text('Watch'));
    await settleDialog(tester);
    expect(controller.movesUsed, 0);
  });

  testWidgets('le deuxième indice demande avant de dépenser', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final progress = await ProgressService.load();

    // Grille soluble : sans solution, le solveur n'a aucun coup à désigner et
    // l'indice n'aurait rien à rendre.
    final level = LevelPattern.parse([
      '>...',
      '....',
      '...<',
      '....',
    ], id: 1).copyWith(optimalMoves: 6);

    await tester.pumpWidget(
      MaterialApp(
        theme: UngridTheme.build(),
        home: GameScreen(
          levelId: 1,
          repository: LevelRepository(fixedLevels: [level], lastLevel: 1),
          progress: progress,
          haptics: HapticService(enabled: false),
        ),
      ),
    );
    await settleDialog(tester);
    final controller = tester
        .widget<GameBoard>(find.byType(GameBoard))
        .controller;

    await tester.tap(find.text('HINT'));
    await settleDialog(tester);
    expect(find.text('One more hint?'), findsNothing);
    expect(controller.hintedBlockId, isNotNull);

    await tester.tap(find.text('HINT'));
    await settleDialog(tester);
    expect(find.text('One more hint?'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await settleDialog(tester);
  });
}
