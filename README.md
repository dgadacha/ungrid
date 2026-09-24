# UNGRID

Puzzle mobile : videz la grille avant de manquer de coups.

Touchez un bloc, il glisse dans la direction de sa flèche jusqu'à l'obstacle
suivant — ou hors de la grille. Chaque tap compte, même celui qui ne déplace
rien.

## Démarrer

```bash
flutter run
```

La campagne principale compte **100 niveaux avec tuiles de rotation**, tous dans le style
validé à partir du niveau 10 du lot d’essai. Elle démarre directement au niveau
défi et progresse vers des grilles expertes. Aucun niveau facile n’est généré après la fin du catalogue.

La campagne utilise une sauvegarde séparée : elle démarre au niveau 1, tandis
que les anciens records restent conservés. Le générateur historique v2 reste disponible pour les anciens catalogues.

Le lot expérimental de 20 niveaux reste accessible dans
**Settings → Playtest → 20-LEVEL CHALLENGE**, sans sauvegarde.
Voir [le rapport de campagne](docs/campaign-100.md) et
[le premier lot d’essai](docs/playtest-20.md).

## Maîtrise et récompenses

Les niveaux sont regroupés en chapitres de dix. Résoudre un chapitre donne une
médaille ; le maîtriser entièrement la rend dorée. Une victoire sans indice ni
coups supplémentaires obtient MASTERED, annulations autorisées. Après une
défaite, UNDO MOVE reprend le dernier déplacement.

REWARDS permet d'équiper les palettes gagnées après 1, 3 et 5 médailles.
La nouvelle mécanique se teste dans **Settings → Playtest → FRAGILE · 10** :
un arrêt fendu disparaît quand son premier occupant repart.
Voir [les règles et les récompenses](docs/engagement.md).

## Tests

```bash
flutter test
```

L'épreuve de fond génère mille niveaux et vérifie qu'ils sont tous jouables,
reproductibles et fabriqués assez vite pour que personne ne s'en aperçoive.

Le détail des règles et de l'architecture est dans [CLAUDE.md](CLAUDE.md).

Tuiles de rotation : Settings → Playtest → **ROTATION · 10**. Le générateur dédié vérifie leur usage et le budget optimal ; voir [les règles et la génération](docs/rotation.md).

La campagne active v4 embarque ses grilles vérifiées et se génère avec `tool/build_planning_campaign.dart`. Elle exige au moins trois retours différés dans sa solution optimale de référence, quatre pour les niveaux 81–100, et au moins 16 coups. PLAY lance directement les 100 niveaux ; le lot Playtest de 10 reste disponible.

Le retour sur le niveau 81 a conduit à revoir la sélection : voir [les critères de planification](docs/planning-difficulty.md).
