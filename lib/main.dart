import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'game/campaign/campaign_catalog.dart';
import 'services/progress_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait seulement : la grille est pensée pour le pouce, verticalement.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  final progress = await ProgressService.load();

  // La campagne publiée : c'est elle qui décide quel puzzle porte quel numéro.
  // Si le fichier manque, le jeu tourne avec des niveaux fabriqués à la volée
  // plutôt que de refuser de démarrer.
  CampaignCatalog? catalog;
  try {
    catalog = await CampaignCatalog.load();
  } catch (error) {
    debugPrint('Campagne introuvable, génération à la volée : $error');
  }

  runApp(UngridApp(progress: progress, catalog: catalog));
}
