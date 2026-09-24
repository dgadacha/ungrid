# Campagne principale v4 — planification

PLAY ouvre `assets/levels/campaign_v4.json`, avec 100 grilles distinctes à rotations. Cette sélection remplace la v3 après le retour du joueur : son niveau 81 a été résolu en 14 secondes malgré un score de difficulté élevé.

## Changement de sélection

La solution v3 du niveau 81 demandait 12 coups et un seul retour à un bloc après avoir joué d'autres blocs. La nouvelle campagne demande :

- 16 à 26 coups optimaux, sans coups de marge.
- Au moins trois retours différés dans la solution optimale retenue.
- De quatre à neuf retours différés pour les niveaux 81–100.
- Une à trois rotations, toutes utilisées dans la solution.
- Au maximum une réussite parmi 24 parcours privilégiant les sorties immédiates.
- Des alternatives entièrement analysées, avec les contrôles de dépendance et de trivialité conservés.

Le nouveau niveau 81 compte 16 coups, quatre retours différés et aucune réussite des 24 parcours simples. Les niveaux sont ordonnés par retours différés puis par le score historique. Un score historique élevé ne suffit plus à devenir un niveau expert.

Les 100 grilles sont distinctes, mais certaines reprennent une même disposition de blocs avec des directions et rotations différentes. Ces mesures portent sur la solution retenue et ne prouvent pas que toutes les solutions demandent autant de retours. Elles ne garantissent pas non plus une durée de réflexion humaine : le prochain playtest doit confirmer la difficulté perçue.

## Construction

113 candidats distincts ont été validés avant la sélection de 100. Les variantes initiales viennent des campagnes v2/v3 (seeds 1–160 000) ; une seconde passe utilise les candidats de `assets/levels/campaign_v4_sources.json` (seeds 160 001–162 000).

```sh
dart compile exe tool/build_planning_campaign.dart -o /tmp/ungrid-planning
# Exécuter les plages de 20 000 seeds entre 1 et 160 000 :
/tmp/ungrid-planning 1 20000
# ... 20001 40000, ..., 140001 160000
/tmp/ungrid-planning 160001 162000 assets/levels/campaign_v4_sources.json
/tmp/ungrid-planning --merge build/planning_campaign/candidates_*.jsonl
flutter test
flutter analyze
```

Chaque candidat accepté est sauvegardé en JSONL. Relancer une plage reprend après sa dernière seed acceptée. Les fichiers exportés sont dans `build/planning_campaign/` ; après vérification, le catalogue et les solutions sont copiés dans `assets/levels/`. Seul le catalogue est embarqué.

## Sauvegardes et vérification

La campagne active utilise `campaign_4_generator_4` et démarre au niveau 1. Les records v2/v3 restent conservés séparément. Les tests rejouent les 100 solutions, recalculent les budgets et les filtres de difficulté, vérifient les empreintes et la limite au niveau 100. Les tests des campagnes précédentes restent conservés.

Voir [le diagnostic détaillé](planning-difficulty.md).
