import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ungrid/game/engine/generator_version.dart';
import 'package:ungrid/game/levels/level_repository.dart';
import 'package:ungrid/screens/home_screen.dart';
import 'package:ungrid/services/haptic_service.dart';
import 'package:ungrid/services/progress_service.dart';

Future<void> pumpHome(WidgetTester tester, ProgressService progress) async {
  await tester.pumpWidget(MaterialApp(
    home: HomeScreen(
      repository: LevelRepository(catalog: null, useIsolate: false),
      progress: progress,
      haptics: HapticService(enabled: false),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('la remise à zéro est annoncée au joueur', (tester) async {
    // Une progression d'avant la mécanique : elle porte sur d'autres boards.
    SharedPreferences.setMockInitialValues({
      'highest_unlocked_level': 9,
      'level_3_completed': true,
    });

    await pumpHome(tester, await ProgressService.load());
    expect(find.textContaining('progress and records were reset'),
        findsOneWidget,
        reason: 'le joueur doit savoir pourquoi son compte est à zéro');

    // Le compte est bien reparti de zéro.
    expect(find.text('LEVEL 1'), findsOneWidget);
  });

  // Le lancement suivant : la version est inscrite, plus rien n'est effacé ni
  // annoncé. C'est ce que vérifie aussi progress_service_test, côté données.
  testWidgets('rien ne s\'affiche quand la progression est à jour',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'progress_generator_version': currentGeneratorVersion,
      'highest_unlocked_level': 9,
    });

    await pumpHome(tester, await ProgressService.load());
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('LEVEL 9'), findsOneWidget);
  });
}
