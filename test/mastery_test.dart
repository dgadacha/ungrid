import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ungrid/game/controllers/game_controller.dart';
import 'package:ungrid/game/levels/level_pattern.dart';
import 'package:ungrid/services/haptic_service.dart';
import 'package:ungrid/services/progress_service.dart';

GameController game() => GameController(
  level: LevelPattern.parse(['>^..', '....', '....', '....'], id: 1),
  haptics: HapticService(enabled: false),
);
void win(GameController c) {
  c.tapCell(1, 0);
  c.tapCell(0, 0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'la défaite se reprend et les annulations restent compatibles avec la maîtrise',
    () {
      final c = game();
      c.tapCell(0, 0); // refus, toujours dû
      c.tapCell(1, 0); // sortie, dernier coup
      expect(c.isOutOfMoves, isTrue);
      expect(c.canUndo, isTrue);
      c.undo();
      expect(c.isPlaying, isTrue);
      expect(c.movesLeft, 1);
      expect(c.remainingBlocks, 2);
      c.restart();
      c.lockInput(Duration.zero);
      c.tapCell(1, 0);
      c.undo();
      win(c);
      expect(c.mastered, isTrue);
      c.dispose();
    },
  );
  test(
    'indice et coups supplémentaires sont des victoires assistées',
    () async {
      final hinted = game();
      expect(await hinted.requestHint(), isTrue);
      win(hinted);
      expect(hinted.isCleared, isTrue);
      expect(hinted.mastered, isFalse);
      final extra = game();
      extra.tapCell(0, 0);
      extra.tapCell(1, 0);
      expect(await extra.requestExtraMoves(), isTrue);
      extra.tapCell(0, 0);
      expect(extra.isCleared, isTrue);
      expect(extra.mastered, isFalse);
      hinted.dispose();
      extra.dispose();
    },
  );
  test(
    'maîtrise persistante, récompenses non cumulables et sélection verrouillée',
    () async {
      SharedPreferences.setMockInitialValues({});
      var p = await ProgressService.load(campaignId: 'test');
      await expectLater(p.selectPalette(1), throwsStateError);
      for (var id = 1; id <= 10; id++) {
        await p.recordCompletion(
          levelId: id,
          movesUsed: 10,
          time: const Duration(seconds: 30),
          mastered: true,
        );
      }
      await p.selectPalette(1);
      await p.recordCompletion(
        levelId: 1,
        movesUsed: 15,
        time: const Duration(seconds: 20),
      );
      p = await ProgressService.load(campaignId: 'test');
      expect(p.chapterCleared(1), 10);
      expect(p.chapterMastered(1), 10);
      expect(p.completedChapters, 1);
      expect(p.paletteIndex, 1);
      expect(p.isMastered(1), isTrue);
      expect(p.unlockedPalettes, [0, 1]);
      await p.resetProgress();
      expect(p.chapterMastered(1), 0);
      expect(p.paletteIndex, 0);
      expect(p.completedChapters, 0);
    },
  );
}
