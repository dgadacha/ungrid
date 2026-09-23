import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ungrid/game/campaign/campaign_catalog.dart';
import 'package:ungrid/game/levels/level_repository.dart';

/// Ce que PLAY doit coûter : rien.
///
/// Les cent niveaux publiés portent leur grille ; les ouvrir ne demande qu'une
/// lecture. Si quelqu'un remet le solveur ou le générateur dans ce chemin, la
/// mesure le dira avant le joueur — une résolution coûte des dizaines de
/// millisecondes par niveau, et se voit à l'ouverture.
void main() {
  test('les cent niveaux se chargent sans repasser par le solveur', () async {
    final catalog = CampaignCatalog.parse(
      await File(CampaignCatalog.assetPath).readAsString(),
    );
    final repository = LevelRepository(
      catalog: catalog,
      lastLevel: CampaignCatalog.assetPath.isEmpty ? null : 100,
      useIsolate: false,
    );

    final watch = Stopwatch()..start();
    for (var id = 1; id <= catalog.levelCount; id++) {
      final level = repository.levelForSync(id);
      expect(level.id, id);
      expect(level.isStructurallyValid, isTrue);
      expect(
        repository.moveLimitFor(id, level),
        level.optimalMoves,
        reason: 'niveau $id : la réserve vaut l\'optimal',
      );
    }
    watch.stop();

    expect(
      watch.elapsedMilliseconds,
      lessThan(500),
      reason: 'chargés en ${watch.elapsedMilliseconds} ms : le solveur est '
          'probablement revenu dans le chemin d\'ouverture',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));
}
