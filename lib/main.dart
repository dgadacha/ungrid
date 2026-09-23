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
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  // La campagne embarquée fixe tous les niveaux proposés au joueur.
  // Une erreur de chargement ne doit pas servir une grille facile à sa place.
  final catalog = await CampaignCatalog.load();
  final progress = await ProgressService.load(
    campaignId:
        'campaign_${catalog.campaign.catalogVersion}_generator_${catalog.campaign.generatorVersion}',
  );

  runApp(UngridApp(progress: progress, catalog: catalog));
}
