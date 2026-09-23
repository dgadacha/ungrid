// flutter test test/render_progression.dart
// Aperçus reproductibles dans build/progression-preview/.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ungrid/app/theme.dart';
import 'package:ungrid/game/campaign/campaign_catalog.dart';
import 'package:ungrid/game/levels/level_repository.dart';
import 'package:ungrid/game/models/level.dart';
import 'package:ungrid/screens/home_screen.dart';
import 'package:ungrid/screens/game_screen.dart';
import 'package:ungrid/screens/level_select_screen.dart';
import 'package:ungrid/screens/rewards_screen.dart';
import 'package:ungrid/services/haptic_service.dart';
import 'package:ungrid/services/progress_service.dart';
import 'package:ungrid/widgets/level_complete_overlay.dart';

void main() {
  testWidgets('aperçus progression et grille fragile sans débordement', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('NunitoSans')
      ..addFont(rootBundle.load('assets/fonts/NunitoSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NunitoSans-ExtraBold.ttf'));
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    SharedPreferences.setMockInitialValues({});
    final p = await ProgressService.load();
    for (var id = 1; id <= 17; id++) {
      await p.recordCompletion(
        levelId: id,
        movesUsed: 12,
        time: const Duration(seconds: 34),
        mastered: id <= 10 || id.isEven,
      );
    }
    final catalog = await CampaignCatalog.load();
    final repository = LevelRepository(catalog: catalog, lastLevel: 100);
    final raw =
        jsonDecode(await rootBundle.loadString('assets/levels/fragile_v1.json'))
            as Map;
    final levels = [
      for (final entry in raw['levels'] as List)
        Level.fromJson(entry as Map<String, dynamic>),
    ];
    final rotationData =
        jsonDecode(
              await rootBundle.loadString('assets/levels/rotation_v1.json'),
            )
            as Map;
    final rotations = [
      for (final raw in rotationData['levels'] as List)
        Level.fromJson(raw as Map<String, dynamic>),
    ];
    final screens = <String, Widget>{
      'home': HomeScreen(
        repository: repository,
        progress: p,
        haptics: HapticService(enabled: false),
      ),
      'chapters': LevelSelectScreen(
        repository: repository,
        progress: p,
        haptics: HapticService(enabled: false),
      ),
      'rewards': RewardsScreen(progress: p),
      'victory': Scaffold(
        backgroundColor: UngridColors.background,
        body: LevelCompleteOverlay(
          movesUsed: 12,
          elapsed: const Duration(seconds: 34),
          records: const RecordsBeaten.none(),
          onNext: () {},
          onReplay: () {},
          allowTapAnywhere: false,
          mastered: true,
          chapter: 2,
          chapterCleared: 7,
        ),
      ),
      'rotation': GameScreen(
        levelId: 1,
        repository: LevelRepository(fixedLevels: rotations, lastLevel: 10),
        progress: p,
        haptics: HapticService(enabled: false),
        playtest: true,
      ),
      'fragile': GameScreen(
        levelId: 1,
        repository: LevelRepository(fixedLevels: levels, lastLevel: 10),
        progress: p,
        haptics: HapticService(enabled: false),
        playtest: true,
      ),
    };
    for (final entry in screens.entries) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: UngridTheme.build(),
            home: entry.value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (entry.key == 'home') {
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/images/logo.png'),
            key.currentContext!,
          ),
        );
        await tester.pump();
      }
      expect(tester.takeException(), isNull, reason: entry.key);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/progression-preview').createSync(recursive: true);
        File(
          'build/progression-preview/${entry.key}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      tester.view.physicalSize = const Size(320, 568);
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: '${entry.key} petit écran',
      );
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
