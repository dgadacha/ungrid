import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ungrid/app/theme.dart';
import 'package:ungrid/game/levels/level_repository.dart';
import 'package:ungrid/game/levels/level_pattern.dart';
import 'package:ungrid/screens/game_screen.dart';
import 'package:ungrid/services/haptic_service.dart';
import 'package:ungrid/services/progress_service.dart';
import 'package:ungrid/widgets/game_board.dart';

void main() {
  testWidgets(
    'reprendre une défaite, maîtriser un niveau, débloquer en coulisses',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final p = await ProgressService.load();
      for (var id = 1; id <= 9; id++) {
        await p.recordCompletion(
          levelId: id,
          movesUsed: 2,
          time: const Duration(seconds: 30),
        );
      }
      final level = LevelPattern.parse([
        '>^..',
        '....',
        '....',
        '....',
      ], id: 10);
      await tester.pumpWidget(
        MaterialApp(
          theme: UngridTheme.build(),
          home: GameScreen(
            levelId: 10,
            repository: LevelRepository(fixedLevels: [level], lastLevel: 10),
            progress: p,
            haptics: HapticService(enabled: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final c = tester.widget<GameBoard>(find.byType(GameBoard)).controller;
      c.tapCell(0, 0);
      c.tapCell(1, 0);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('OUT OF MOVES'), findsOneWidget);
      await tester.tap(find.text('UNDO MOVE'));
      await tester.pump();
      expect(c.isPlaying, isTrue);
      expect(find.text('OUT OF MOVES'), findsNothing);
      c.restart();
      c.lockInput(Duration.zero);
      c.tapCell(1, 0);
      c.tapCell(0, 0);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('MASTERED'), findsOneWidget);
      // Les palettes se débloquent toujours, mais plus rien ne l'annonce :
      // l'écran qui les montrait a été retiré.
      expect(find.textContaining('UNLOCKED'), findsNothing);
      expect(p.chapterCleared(1), 10);
      expect(p.isMastered(10), isTrue);
      expect(p.unlockedPalettes, [0, 1]);
      expect(tester.takeException(), isNull);
    },
  );
}
