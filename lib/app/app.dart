import 'package:flutter/material.dart';

import '../game/campaign/campaign_catalog.dart';
import '../game/levels/level_repository.dart';
import '../screens/home_screen.dart';
import '../services/haptic_service.dart';
import '../services/progress_service.dart';
import 'strings.dart';
import 'theme.dart';

/// Racine de l'application. Les services vivent ici et descendent par
/// constructeur : à cette taille, une injection plus savante n'apporterait
/// rien.
class UngridApp extends StatefulWidget {
  const UngridApp({super.key, required this.progress, this.catalog});

  final ProgressService progress;

  /// La campagne publiée, `null` si le fichier manque.
  final CampaignCatalog? catalog;

  @override
  State<UngridApp> createState() => _UngridAppState();
}

class _UngridAppState extends State<UngridApp> {
  late final HapticService _haptics = HapticService(
    enabled: widget.progress.hapticsEnabled,
  );

  late AppLanguage _language = widget.progress.language;
  late UngridBackground _background = widget.progress.background;

  @override
  void initState() {
    super.initState();
    UngridColors.apply(_background);
  }

  /// Change le fond et reconstruit l'interface.
  Future<void> _setBackground(UngridBackground choice) async {
    if (choice == _background) return;
    await widget.progress.setBackground(choice);
    if (!mounted) return;
    setState(() {
      _background = choice;
      UngridColors.apply(choice);
    });
  }

  /// Change la langue et reconstruit toute l'interface.
  Future<void> _setLanguage(AppLanguage language) async {
    if (language == _language) return;
    await widget.progress.setLanguage(language);
    if (mounted) setState(() => _language = language);
  }

  late final LevelRepository _repository = LevelRepository(
    catalog: widget.catalog,
    lastLevel: widget.catalog?.levelCount,
  );

  @override
  Widget build(BuildContext context) {
    return LanguageScope(
      strings: Strings(_language),
      child: MaterialApp(
        title: 'UNGRID',
        debugShowCheckedModeBanner: false,
        theme: UngridTheme.build(),
        home: HomeScreen(
          repository: _repository,
          progress: widget.progress,
          haptics: _haptics,
          onLanguageChanged: _setLanguage,
          onBackgroundChanged: _setBackground,
        ),
      ),
    );
  }
}
