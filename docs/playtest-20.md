# UNGRID — lot d’essai de 20 niveaux

Accès : **Settings → Playtest → 20-LEVEL CHALLENGE**. Choisir le niveau 1 et jouer avec NEXT ; FINISH au niveau 20 revient au sélecteur. CAMPAIGN permet de revenir aux niveaux de la campagne principale. Le lot est un essai sans sauvegarde, indépendant de la campagne.

## Sélection

6 000 seeds examinées, 2 597 candidats entièrement analysés. Les grilles utilisent le générateur v2 existant, sans changement des règles ni des seeds déjà utilisées. Chaque budget est la solution optimale, et chaque solution exportée a été rejouée dans le moteur.

Les cibles sont définies dans `lib/game/campaign/playtest_plan.dart`. Le sélecteur privilégie les choix qui peuvent coûter des coups, les dépendances entre blocs et les étapes où un seul des mouvements possibles reste optimal. Il limite les coups triviaux, écarte toute analyse incomplète et exige que toutes les tuiles soient utilisées. La sélection échoue si un palier ne trouve aucun candidat : elle ne remplace pas silencieusement un défi par une grille facile.

Le premier chapitre introduit progressivement les choix et les tuiles. Les suivants suivent le rythme découverte, application, défi, respiration, combinaison. Les noms de chapitre indiquent une intention de progression ; ils ne prouvent pas une profondeur d’anticipation particulière.

| Niveau | Phase | Blocs | Coups | Score calculé / 100 |
| --- | --- | ---: | ---: | ---: |
| 1 | Introduction | 5 | 6 | 21.2 |
| 2 | Introduction | 5 | 6 | 34.7 |
| 3 | Introduction | 7 | 9 | 40.0 |
| 4 | Introduction | 8 | 10 | 43.0 |
| 5 | Introduction | 9 | 11 | 52.0 |
| 6 | Discover | 9 | 11 | 40.1 |
| 7 | Practice | 9 | 11 | 48.0 |
| 8 | Challenge | 10 | 11 | 53.9 |
| 9 | Breathe | 9 | 11 | 44.0 |
| 10 | Combine | 11 | 13 | 60.8 |
| 11 | Discover | 10 | 14 | 46.0 |
| 12 | Practice | 8 | 10 | 56.0 |
| 13 | Challenge | 9 | 9 | 62.0 |
| 14 | Breathe | 9 | 12 | 49.0 |
| 15 | Combine | 12 | 14 | 68.1 |
| 16 | Discover | 7 | 12 | 51.0 |
| 17 | Practice | 10 | 10 | 61.0 |
| 18 | Challenge | 10 | 12 | 66.7 |
| 19 | Breathe | 9 | 12 | 54.0 |
| 20 | Combine | 9 | 11 | 75.2 |

## Évaluer avec des joueurs

Ces scores sont des indicateurs du solveur, pas une difficulté humaine mesurée. Pour un premier test, observer quelques nouveaux joueurs sur les niveaux 1 à 5 puis 8 à 10 ; proposer 15 et 20 aux plus à l’aise. Relever le temps de réflexion, les annulations, les indices, les abandons et le choix de continuer. Aucune collecte automatique ni service externe n’est ajouté.

Après une réussite, demander ce qui a permis de comprendre la solution. Après un échec, vérifier si le joueur peut expliquer son erreur. Une difficulté intéressante doit être compréhensible ; augmenter simplement le nombre d’essais ne constitue pas un succès.

## Reproduire une proposition

```sh
dart compile exe tool/build_playtest.dart -o /tmp/ungrid-playtest
/tmp/ungrid-playtest 6000
flutter test test/playtest_campaign_test.dart
```

Le générateur écrit dans `build/playtest/` pour permettre une comparaison avant intégration. Les trois fichiers retenus sont versionnés dans `assets/levels/` ; seul le catalogue est embarqué dans l’application. Pour conserver les associations niveau/seed du lot v1 après diffusion, publier un nouveau lot sous un autre nom plutôt que remplacer ces fichiers.
