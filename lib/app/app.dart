import 'package:flutter/material.dart';

import '../game/campaign/campaign_catalog.dart';
import '../game/levels/level_repository.dart';
import '../screens/home_screen.dart';
import '../services/haptic_service.dart';
import '../services/progress_service.dart';
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
  late final HapticService _haptics =
      HapticService(enabled: widget.progress.hapticsEnabled);
  late final LevelRepository _repository =
      LevelRepository(catalog: widget.catalog);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNGRID',
      debugShowCheckedModeBanner: false,
      theme: UngridTheme.build(),
      home: HomeScreen(
        repository: _repository,
        progress: widget.progress,
        haptics: _haptics,
      ),
    );
  }
}
