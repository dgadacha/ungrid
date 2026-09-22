import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ungrid/services/progress_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProgressService progress;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    progress = await ProgressService.load();
  });

  test('seul le premier niveau est ouvert au départ', () {
    expect(progress.highestUnlockedLevel, 1);
    expect(progress.isUnlocked(1), isTrue);
    expect(progress.isUnlocked(2), isFalse);
    expect(progress.progressFor(1), isNull);
  });

  test('terminer un niveau ouvre le suivant', () async {
    await progress.recordCompletion(
      levelId: 1,
      movesUsed: 4,
      time: const Duration(milliseconds: 8200),
    );

    expect(progress.highestUnlockedLevel, 2);
    final saved = progress.progressFor(1)!;
    expect(saved.completed, isTrue);
    expect(saved.bestMovesUsed, 4);
    expect(saved.bestTime, const Duration(milliseconds: 8200));
  });

  test('un premier passage ne compte pas comme un record', () async {
    final records = await progress.recordCompletion(
      levelId: 1,
      movesUsed: 4,
      time: const Duration(seconds: 8),
    );
    expect(records.any, isFalse);
  });

  test('les records ne reculent pas', () async {
    await progress.recordCompletion(
      levelId: 1,
      movesUsed: 4,
      time: const Duration(seconds: 8),
    );
    final records = await progress.recordCompletion(
      levelId: 1,
      movesUsed: 9,
      time: const Duration(seconds: 30),
    );

    expect(records.any, isFalse);
    final saved = progress.progressFor(1)!;
    expect(saved.bestMovesUsed, 4);
    expect(saved.bestTime, const Duration(seconds: 8));
  });

  test('les deux records sont indépendants', () async {
    await progress.recordCompletion(
      levelId: 2,
      movesUsed: 14,
      time: const Duration(seconds: 40),
    );

    // Plus rapide, mais avec plus de coups : seul le temps est battu.
    var records = await progress.recordCompletion(
      levelId: 2,
      movesUsed: 17,
      time: const Duration(seconds: 31),
    );
    expect(records.time, isTrue);
    expect(records.moves, isFalse);

    // Puis l'inverse.
    records = await progress.recordCompletion(
      levelId: 2,
      movesUsed: 12,
      time: const Duration(seconds: 55),
    );
    expect(records.time, isFalse);
    expect(records.moves, isTrue);

    final saved = progress.progressFor(2)!;
    expect(saved.bestMovesUsed, 12);
    expect(saved.bestTime, const Duration(seconds: 31));
  });

  test('battre les deux en une partie est signalé', () async {
    await progress.recordCompletion(
      levelId: 3,
      movesUsed: 20,
      time: const Duration(seconds: 60),
    );
    final records = await progress.recordCompletion(
      levelId: 3,
      movesUsed: 15,
      time: const Duration(seconds: 42),
    );
    expect(records.both, isTrue);
  });

  test('rejouer un ancien niveau ne referme pas la progression', () async {
    await progress.recordCompletion(
        levelId: 1, movesUsed: 4, time: const Duration(seconds: 8));
    await progress.recordCompletion(
        levelId: 2, movesUsed: 7, time: const Duration(seconds: 9));
    expect(progress.highestUnlockedLevel, 3);

    await progress.recordCompletion(
        levelId: 1, movesUsed: 4, time: const Duration(seconds: 7));
    expect(progress.highestUnlockedLevel, 3);
  });

  test('les niveaux terminés se comptent', () async {
    await progress.recordCompletion(
        levelId: 1, movesUsed: 4, time: const Duration(seconds: 1));
    await progress.recordCompletion(
        levelId: 2, movesUsed: 7, time: const Duration(seconds: 1));
    expect(progress.completedCount(), 2);
  });

  test('les vibrations sont actives par défaut et se retiennent', () async {
    expect(progress.hapticsEnabled, isTrue);
    await progress.setHapticsEnabled(false);
    expect(progress.hapticsEnabled, isFalse);
  });

  test('effacer la progression remet tout à zéro', () async {
    await progress.recordCompletion(
        levelId: 1, movesUsed: 4, time: const Duration(seconds: 1));
    await progress.recordCompletion(
        levelId: 2, movesUsed: 4, time: const Duration(seconds: 1));
    await progress.resetProgress();

    expect(progress.highestUnlockedLevel, 1);
    expect(progress.completedCount(), 0);
    expect(progress.progressFor(1), isNull);
  });
}
