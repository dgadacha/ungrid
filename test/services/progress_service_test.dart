import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ungrid/game/engine/generator_version.dart';
import 'package:ungrid/services/progress_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la v3 annonce le changement et conserve la progression v2', () async {
    SharedPreferences.setMockInitialValues({});
    final old = await ProgressService.load(
      campaignId: 'campaign_2_generator_2',
    );
    await old.recordCompletion(
      levelId: 7,
      movesUsed: 14,
      time: const Duration(seconds: 30),
      mastered: true,
    );
    final fresh = await ProgressService.load(
      campaignId: 'campaign_3_generator_3',
    );
    expect(fresh.startedNewCampaign, isTrue);
    expect(fresh.highestUnlockedLevel, 1);
    expect(fresh.isCompleted(7), isFalse);
    final saved = await ProgressService.load(
      campaignId: 'campaign_2_generator_2',
    );
    expect(saved.highestUnlockedLevel, 8);
    expect(saved.isMastered(7), isTrue);
    final reload = await ProgressService.load(
      campaignId: 'campaign_3_generator_3',
    );
    expect(reload.startedNewCampaign, isFalse);
  });

  late ProgressService progress;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    progress = await ProgressService.load();
  });

  test(
    'la nouvelle campagne conserve les records historiques séparément',
    () async {
      await progress.recordCompletion(
        levelId: 12,
        movesUsed: 14,
        time: const Duration(seconds: 30),
      );
      await progress.setHapticsEnabled(false);
      final challenge = await ProgressService.load(
        campaignId: 'campaign_2_generator_2',
      );
      expect(challenge.highestUnlockedLevel, 1);
      expect(challenge.progressFor(12), isNull);
      expect(challenge.startedNewCampaign, isTrue);
      expect(challenge.hapticsEnabled, isFalse);
      await challenge.recordCompletion(
        levelId: 1,
        movesUsed: 13,
        time: const Duration(seconds: 40),
      );
      final reloaded = await ProgressService.load(
        campaignId: 'campaign_2_generator_2',
      );
      expect(reloaded.highestUnlockedLevel, 2);
      expect(reloaded.startedNewCampaign, isFalse);
      final previous = await ProgressService.load();
      expect(previous.highestUnlockedLevel, 13);
      expect(previous.progressFor(12)!.bestMovesUsed, 14);
      await reloaded.resetProgress();
      expect(previous.progressFor(12)!.bestTime, const Duration(seconds: 30));
      expect(previous.hapticsEnabled, isFalse);
    },
  );

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
      levelId: 1,
      movesUsed: 4,
      time: const Duration(seconds: 8),
    );
    await progress.recordCompletion(
      levelId: 2,
      movesUsed: 7,
      time: const Duration(seconds: 9),
    );
    expect(progress.highestUnlockedLevel, 3);

    await progress.recordCompletion(
      levelId: 1,
      movesUsed: 4,
      time: const Duration(seconds: 7),
    );
    expect(progress.highestUnlockedLevel, 3);
  });

  test('les niveaux terminés se comptent', () async {
    await progress.recordCompletion(
      levelId: 1,
      movesUsed: 4,
      time: const Duration(seconds: 1),
    );
    await progress.recordCompletion(
      levelId: 2,
      movesUsed: 7,
      time: const Duration(seconds: 1),
    );
    expect(progress.completedCount(), 2);
  });

  test('les vibrations sont actives par défaut et se retiennent', () async {
    expect(progress.hapticsEnabled, isTrue);
    await progress.setHapticsEnabled(false);
    expect(progress.hapticsEnabled, isFalse);
  });

  test('effacer la progression remet tout à zéro', () async {
    await progress.recordCompletion(
      levelId: 1,
      movesUsed: 4,
      time: const Duration(seconds: 1),
    );
    await progress.recordCompletion(
      levelId: 2,
      movesUsed: 4,
      time: const Duration(seconds: 1),
    );
    await progress.resetProgress();

    expect(progress.highestUnlockedLevel, 1);
    expect(progress.completedCount(), 0);
    expect(progress.progressFor(1), isNull);
  });

  group('changement de générateur', () {
    test('une première installation ne perd rien', () async {
      SharedPreferences.setMockInitialValues({});
      final fresh = await ProgressService.load();

      expect(
        fresh.wasResetForNewLevels,
        isFalse,
        reason: 'il n\'y avait aucune progression à effacer',
      );
      expect(fresh.highestUnlockedLevel, 1);
    });

    test('une progression d\'avant la mécanique s\'efface', () async {
      // Aucune version inscrite : ces records viennent forcément d'un
      // générateur antérieur, donc d'autres boards.
      SharedPreferences.setMockInitialValues({
        'highest_unlocked_level': 12,
        'level_7_completed': true,
        'level_7_best_moves': 9,
        'level_7_best_time': 41000,
        'haptics_enabled': false,
      });
      final migrated = await ProgressService.load();

      expect(migrated.wasResetForNewLevels, isTrue);
      expect(migrated.highestUnlockedLevel, 1);
      expect(migrated.isCompleted(7), isFalse);
      expect(
        migrated.progressFor(7),
        isNull,
        reason: 'le record portait sur un puzzle qui n\'existe plus',
      );
      expect(
        migrated.hapticsEnabled,
        isFalse,
        reason: 'un réglage ne dépend pas des boards : il survit',
      );
    });

    test('une progression à jour est conservée', () async {
      SharedPreferences.setMockInitialValues({
        'progress_generator_version': currentGeneratorVersion,
        'highest_unlocked_level': 12,
        'level_7_completed': true,
        'level_7_best_moves': 9,
      });
      final kept = await ProgressService.load();

      expect(kept.wasResetForNewLevels, isFalse);
      expect(kept.highestUnlockedLevel, 12);
      expect(kept.isCompleted(7), isTrue);
      expect(kept.progressFor(7)?.bestMovesUsed, 9);
    });

    test('la version s\'inscrit, et le message ne se répète pas', () async {
      SharedPreferences.setMockInitialValues({
        'progress_generator_version': currentGeneratorVersion - 1,
        'highest_unlocked_level': 5,
      });
      final first = await ProgressService.load();
      expect(first.wasResetForNewLevels, isTrue);
      first.acknowledgeReset();
      expect(first.wasResetForNewLevels, isFalse);

      // Deuxième lancement : la version est à jour, plus rien ne bouge.
      final second = await ProgressService.load();
      expect(second.wasResetForNewLevels, isFalse);
    });
  });
}
