# UNGRID

Puzzle mobile en Flutter. On vide une grille de blocs fléchés avant d'épuiser
ses coups.

## La règle

Toucher un bloc le fait **glisser** dans la direction de sa flèche, aussi loin
qu'il peut aller :

| Situation | Résultat |
| --- | --- |
| Rien jusqu'au bord | le bloc quitte la grille |
| Un obstacle plus loin | le bloc s'arrête sur la dernière case libre |
| Un obstacle collé au bloc | le bloc ne bouge pas |

Dans les trois cas, **le coup est décompté**. C'est ce qui oblige à lire la
grille avant de toucher : un tap à l'aveugle coûte aussi cher qu'un bon.

La direction d'un bloc ne change jamais. Un bloc déplacé reste un obstacle
pour les autres : le déplacer peut ouvrir un passage, en fermer un, ou coincer
définitivement la position.

**Les murs** (`#`) sont des obstacles permanents : ils ne bougent pas, ne
sortent pas, ne se touchent pas, et toucher un mur ne consomme aucun coup. Ils
ne comptent pas dans la condition de victoire.

**Victoire** : la grille est vide. Elle est évaluée *avant* la défaite — vider
la grille avec son dernier coup est une réussite.

**Défaite** : plus de coups et des blocs encore là.

`moveLimit = optimalMoves + moveAllowance`, la marge dépendant de la difficulté
(`moveAllowanceByDifficulty`, de +5 en facile à +2 en expert). C'est le levier
d'équilibrage principal : une même grille devient nettement plus exigeante avec
deux coups de marge qu'avec cinq.

**Le chronomètre ne décide de rien.** Il démarre au premier coup, se suspend
quand l'application passe au second plan, et sert uniquement à battre ses
records. Deux records indépendants par niveau : meilleur temps, meilleur
nombre de coups.

**L'annulation** reprend le dernier déplacement, animé à l'envers, et rend le
coup. Un refus n'a rien déplacé : il n'y a rien à reprendre, et il reste dû.

## Architecture

```
lib/
├── app/            thème, constantes de temps et de forme
├── game/
│   ├── models/     Block, Level, Direction, GridPosition, MoveResult
│   ├── engine/     moteur, solveur, générateur, évaluateurs
│   ├── controllers/  la partie en cours : coups, temps, animations
│   ├── painters/   rendu CustomPainter
│   ├── animations/ déplacements, refus, enfoncement
│   └── levels/     niveaux manuels, parseur ASCII, dépôt
├── screens/        accueil, jeu, sélection, réglages, debug
├── services/       sauvegarde, haptique, récompenses
└── widgets/        grille jouable, bandeau, boutons, écrans de fin
```

Le moteur, le solveur et le générateur n'importent pas Flutter : ils tournent
dans un test, un isolate ou un outil en ligne de commande.

### Le solveur

L'état d'une partie, ce sont les **positions** des blocs : un bloc peut être
joué plusieurs fois avant de sortir. La recherche est un **A\*** dont
l'estimation est le nombre de blocs restants — chacun devra sortir au moins une
fois, donc elle ne surestime jamais, et la première solution trouvée est la plus
courte. Un parcours en largeur explorait des centaines de milliers de
configurations avant d'approcher la sortie.

Un bloc ne se déplaçant que dans sa direction, sa coordonnée ne revient jamais
en arrière : l'espace d'états est sans cycle.

### Le générateur

Génération **par rembobinage** : on part de la grille vide — la victoire — et on
remonte le temps. Deux gestes seulement : faire rentrer un bloc par le bord
(l'inverse d'une sortie), ou reculer un bloc jusqu'à la case d'où il aurait
glissé (l'inverse d'un déplacement). Chaque état traversé est donc gagnable par
construction ; le niveau livré est le dernier, et sa solution est connue avant
que le joueur y touche.

**La chaîne.** Un board se noue quand chaque bloc posé vient barrer la route du
précédent : à tout instant, un seul bloc peut encore quitter la grille, et le
dernier recul referme celui-là. La construction refuse donc les gestes qui ne
referment rien (`_chainOnly`), et repart en mode souple si la contrainte a
étouffé le board. Deux conséquences guident le placement : un bloc collé au bord
dans sa direction ne pourra **jamais** être retenu — il est écarté à la pose —
et `closeExits` prolonge la chaîne d'un bloc quand aucun recul ne referme,
parce que la géométrie change et qu'un recul redevient souvent possible ensuite.

Résultat mesuré sur 150 niveaux : **69 % exigent au moins un repositionnement**
(jouer un bloc deux fois), 17 % n'offrent aucune sortie immédiate, et la part de
blocs sortables au premier coup tombe de 20-27 % à 8-15 %.

Un board tiré au hasard mène presque toujours à une impasse, et le vérifier
coûte une exploration complète : c'est pourquoi on ne tire jamais au hasard.

La génération est **déterministe** : le numéro du niveau suffit à le
reconstruire à l'identique, rien n'est stocké. Le pipeline est
`rembobinage → examens bon marché → solveur → difficulté → aspect → accepter ou
recommencer`.

### Points connus

- Le repositionnement est **préféré, pas exigé** : un candidat qui n'en demande
  aucun garde une distance non nulle, si bien que le pipeline continue de
  chercher sans jamais se retrouver sans rien à proposer. Environ un tiers des
  niveaux restent donc résolubles sans pousser.
- Le mode strict réduit un peu le nombre de blocs (10 au lieu de 12 sur les
  premiers niveaux générés) : c'est le prix du nouage, et il paraît bien payé.
- Le générateur ne construit pas de **piège** délibéré : un board où un coup
  malheureux condamne la partie. `deadEndCount` les compterait, mais A* explore
  trop peu d'états pour en croiser. Ce serait le prochain levier de difficulté.

### Les premiers niveaux

Quatre niveaux d'apprentissage, une idée chacun : le geste, le glissement, le
refus, le repositionnement. Le quatrième est un blocage circulaire à quatre
blocs — rien ne peut sortir, il faut pousser. Chacun porte une phrase, affichée
sous la grille (`ManualLevels.hintFor`). Les suivants n'en ont pas : on apprend
en jouant.

## Outils

```bash
dart run tool/analyze_generated.dart 200   # statistiques de génération
dart run tool/check_manual_levels.dart     # les niveaux écrits tiennent-ils ?
dart run tool/diag_slide.dart              # ce que le rembobinage produit
flutter test                               # dont l'épreuve des 1000 niveaux
```

Compiler les outils en natif (`dart compile exe`) pour mesurer la performance :
en mode debug, tout est plusieurs fois plus lent.

L'écran de **debug de génération** (Réglages → Génération) montre le board, la
solution pas à pas, les scores et les critères non tenus. C'est là qu'on règle
le générateur, pas à l'aveugle.

## Direction artistique

Palette [Flat UI v1](https://flatuicolors.com/palette/defo), fond nuit
(`#2C3E50`), blocs en aplats vifs, flèche encre épaisse, aucun dégradé ni
texture. Les couleurs ne désignent **pas** les directions — la flèche s'en
charge seule, ce qui laisse la couleur libre pour d'autres mécaniques et ne
pénalise pas un joueur daltonien.

La couleur d'un bloc est tirée de son identité, pas de sa case : un bloc qui
glisse ne change pas de teinte.

Police Nunito Sans, portrait uniquement.

## Conventions

- Français pour l'interface, les commentaires et les messages de commit.
- Le moteur ne connaît ni le temps, ni le score : cela appartient au contrôleur.
- Toute règle de jeu modifiée se répercute dans les tests du même coup.
- Les niveaux s'écrivent en ASCII (`^ v < >` et `#`), lisibles et modifiables.
