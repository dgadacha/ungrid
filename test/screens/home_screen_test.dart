import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ungrid/game/engine/generator_version.dart';
import 'package:ungrid/game/campaign/campaign_catalog.dart';
import 'package:ungrid/game/levels/level_repository.dart';
import 'package:ungrid/screens/home_screen.dart';
import 'package:ungrid/services/haptic_service.dart';
import 'package:ungrid/services/progress_service.dart';
import 'package:ungrid/widgets/game_board.dart';

Future<void> pumpHome(WidgetTester tester, ProgressService progress) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomeScreen(
        repository: LevelRepository(catalog: null, useIsolate: false),
        progress: progress,
        haptics: HapticService(enabled: false),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'après le niveau 100, on peut rejouer sans charger un niveau 101',
    timeout: const Timeout(Duration(seconds: 40)),
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'progress_generator_version': currentGeneratorVersion,
        'highest_unlocked_level': 101,
        'level_100_completed': true,
      });
      // L'horloge d'un test de widget est simulée : une lecture de fichier
      // attendue ici ne reviendrait jamais.
      late final CampaignCatalog catalog;
      await tester.runAsync(() async {
        catalog = CampaignCatalog.parse(
          await File(CampaignCatalog.assetPath).readAsString(),
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            repository: LevelRepository(
              catalog: catalog,
              lastLevel: 100,
              // Sans binding d'isolate sous flutter test, un préchargement
              // parti en arrière-plan ne revient jamais et pumpAndSettle
              // tourne jusqu'au délai de garde.
              useIsolate: false,
            ),
            progress: await ProgressService.load(),
            haptics: HapticService(enabled: false),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('CAMPAIGN COMPLETE'), findsOneWidget);
      await tester.tap(find.text('REPLAY'));
      // Pas de pumpAndSettle : le plateau anime tant qu'il a quelque chose à
      // jouer, et l'attente ne retomberait jamais à zéro frame.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<GameBoard>(find.byType(GameBoard)).controller.level.id,
        100,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('la remise à zéro est annoncée au joueur', (tester) async {
    // Une progression d'avant la mécanique : elle porte sur d'autres boards.
    SharedPreferences.setMockInitialValues({
      'highest_unlocked_level': 9,
      'level_3_completed': true,
    });

    await pumpHome(tester, await ProgressService.load());
    expect(
      find.textContaining('progress and records were reset'),
      findsOneWidget,
      reason: 'le joueur doit savoir pourquoi son compte est à zéro',
    );

    // Le compte est bien reparti de zéro.
    expect(find.text('LEVEL 1'), findsOneWidget);
  });

  // Le lancement suivant : la version est inscrite, plus rien n'est effacé ni
  // annoncé. C'est ce que vérifie aussi progress_service_test, côté données.
  testWidgets('rien ne s\'affiche quand la progression est à jour', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'progress_generator_version': currentGeneratorVersion,
      'highest_unlocked_level': 9,
    });

    await pumpHome(tester, await ProgressService.load());
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('LEVEL 9'), findsOneWidget);
  });
}
