# Campagne principale — 100 défis

Le retour du playtest fixe le niveau 10 comme référence de départ. La campagne principale utilise désormais `assets/levels/campaign_v2.json` : 100 grilles distinctes reconstruites avec le générateur v2 existant. Le lot de 20 niveaux reste inchangé et disponible dans Playtest.

## Critères

- Score calculé minimal : 60 ; minimum effectivement retenu : 61.4.
- 7 à 14 blocs, grilles de 6 × 6 au maximum et une ou deux tuiles utilisées.
- Choix sous-optimaux, dépendances entre blocs et étapes où un seul mouvement reste optimal.
- Au plus 20 % pour la pénalité de trivialité.
- Aucune alternative non analysée ; budget exactement égal à la solution optimale.
- Profil plus strict à partir du niveau 51 ; défi final au-dessus du niveau 20 du playtest selon le score du solveur.

Les rythmes varient à l’intérieur de chaque tranche, mais aucun palier ne revient aux anciens niveaux faciles. Ces métriques sont des indicateurs de sélection ; elles ne garantissent pas le temps de réflexion de chaque joueur.

| Niveaux | Score moyen / 100 | Score minimum | Score maximum |
| --- | ---: | ---: | ---: |
| 1–20 | 62.9 | 61.4 | 65.5 |
| 21–50 | 65.9 | 64.4 | 68.5 |
| 51–80 | 68.9 | 67.3 | 71.7 |
| 81–100 | 72.1 | 70.4 | 78.9 |

Le niveau 100 atteint 78.9, contre 75,2 pour le niveau 20 du lot d’essai.

## Intégration et sauvegarde

PLAY ouvre directement cette campagne. La sélection de niveaux est bornée à 100 ; après la dernière victoire, FINISH revient à l’accueil et REPLAY permet de rejouer le dernier niveau. Aucun niveau 101 facile n’est généré.

La nouvelle campagne commence au niveau 1 avec sa propre sauvegarde (`campaign_2_generator_2`). Les anciens records et niveaux débloqués restent conservés dans leurs clés historiques, sans être appliqués aux nouveaux puzzles. Les préférences haptiques restent partagées. Un message à l’accueil explique le changement si une ancienne progression existe.

## Construction et vérification

Le benchmark existant de 60 000 seeds a présélectionné 740 candidats. Chacun a été reconstruit, résolu et analysé à nouveau avant la sélection finale. La présélection utilise des tolérances sur les valeurs arrondies, mais les critères finaux sont appliqués aux valeurs recalculées.

```sh
dart compile exe tool/build_campaign.dart -o /tmp/ungrid-campaign
/tmp/ungrid-campaign --benchmark benchmark_stop_tiles.json
# Sans benchmark disponible :
/tmp/ungrid-campaign 60000
flutter test
flutter analyze
```

Les propositions sortent dans `build/campaign/` ; leur intégration reste explicite pour protéger les associations niveau/seed publiées. Les solutions et les métriques détaillées accompagnent le catalogue dans `assets/levels/`, mais seul le catalogue est embarqué.

Les tests vérifient les critères sur les 100 grilles, rejouent les solutions dans le moteur, contrôlent la sauvegarde séparée et le retour après la fin de campagne.
