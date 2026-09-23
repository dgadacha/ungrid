# Maîtrise, chapitres et arrêts à usage unique

## Parcours intégré

La campagne conserve ses 100 grilles et sa sauvegarde. Les niveaux sont regroupés en dix chapitres de dix niveaux. Chaque victoire conserve la distinction « résolu » ; une victoire dans le budget initial sans indice ni coups supplémentaires obtient aussi « maîtrisé ». Les annulations sont autorisées. Une maîtrise déjà acquise ne disparaît jamais après une tentative assistée. Les anciennes victoires restent résolues : aucune maîtrise n'est attribuée rétroactivement sans preuve.

L'écran de victoire montre la distinction de la tentative, la progression du chapitre et les nouvelles palettes débloquées. Une médaille est acquise quand les dix niveaux d'un chapitre sont résolus ; elle devient dorée si les dix sont maîtrisés. Les récompenses ne se cumulent pas à chaque replay.

REWARDS, sur l'accueil, permet d'équiper CLASSIC ou les palettes débloquées : LAGOON à une médaille, SUNSET à trois et AURORA à cinq. Les palettes sont cosmétiques et les flèches restent lisibles. Le choix est enregistré dans la sauvegarde de la campagne. La remise à zéro efface ces distinctions et ce choix pour la campagne concernée seulement.

Après une défaite, UNDO MOVE reprend le dernier déplacement et rend son coup, y compris les tuiles consommées. Un refus conserve la règle historique : il coûte un coup et n'a pas de déplacement à annuler. Un redémarrage commence une nouvelle tentative. Une récompense asynchrone d'une tentative précédente est ignorée si le joueur a entre-temps recommencé ou quitté le niveau.

## Dix niveaux de test

Accès : **Settings → Playtest → FRAGILE · 10**. Ce lot est sans sauvegarde, comme le premier playtest, et reste distinct de la campagne publiée.

Un arrêt fragile, dessiné par un losange fendu, retient le premier bloc entrant. Il disparaît quand ce bloc repart, même si celui-ci s'arrête plus loin au lieu de sortir. Un mouvement bloqué ne le consomme pas. Les autres blocs peuvent alors traverser la case sans s'arrêter. Une annulation rétablit exactement l'état précédent.

Le moteur conserve les tuiles consommées dans l'historique. Le solveur inclut leur état dans sa clé de recherche, dans son calcul d'indices et dans l'analyse des alternatives. Les directions restent fixes. Les empreintes et solutions des anciennes grilles sont inchangées : le générateur v2 n'a pas été modifié.

Le lot est issu de 60 candidats retenus : les dix grilles ont un score calculé d'au moins 60, utilisent leurs arrêts, et ont une solution plus courte qu'avec les mêmes arrêts permanents. La disparition intervient donc réellement dans la résolution ; la difficulté humaine reste à tester.

```sh
dart compile exe tool/build_fragile_pack.dart -o /tmp/ungrid-fragile
/tmp/ungrid-fragile
flutter test
flutter test test/render_progression.dart
```

Le générateur écrit dans `build/fragile/`, pour ne pas remplacer implicitement le lot intégré. Le catalogue d'essai définit sa propre version de règles. Les aperçus de l'interface sont produits dans `build/progression-preview/`, sur téléphone de 390 × 844 et avec contrôle des débordements à 320 × 568.

Les portes, rotations, indices progressifs, sauvegardes de parties en cours et objectifs de vitesse ne font pas partie de ce premier ensemble.
