# UNGRID

Puzzle mobile en Flutter. On vide une grille de blocs fléchés avant d'épuiser
ses coups.

## La règle

Toucher un bloc le fait **glisser** dans la direction de sa flèche, aussi loin
qu'il peut aller :

| Situation | Résultat |
| --- | --- |
| Rien jusqu'au bord | le bloc quitte la grille |
| Une tuile d'arrêt sur la route | le bloc entre dessus et s'y pose |
| Un bloc plus loin | le bloc s'arrête sur la dernière case libre |
| Un bloc collé | le bloc ne bouge pas |

Dans tous les cas, **le coup est décompté**. C'est ce qui oblige à lire la
grille avant de toucher : un tap à l'aveugle coûte aussi cher qu'un bon.

La direction d'un bloc ne change jamais. Un bloc déplacé reste un obstacle
pour les autres : le déplacer peut ouvrir un passage, en fermer un, ou coincer
définitivement la position.

**Les tuiles d'arrêt** (`o`) sont des cases fixes qui retiennent un bloc
*entrant* dessus. Elles ne bougent pas, ne sortent pas, ne se touchent pas, ne
comptent pas dans la victoire, et un bloc qui **démarre** sur une tuile n'est
pas retenu par elle — sans quoi la case serait un piège dont rien ne ressort.

Un bloc passe avant une tuile : si un bloc barre la route plus tôt, c'est lui
qui décide. Une tuile ne provoque jamais de refus, puisqu'elle déplace toujours
d'au moins une case.

Les murs permanents ont été retirés du jeu. Ils resserraient la grille sans
jamais rien arrêter dans une solution valide : un bloc arrêté par un mur ne
repartait plus.

**Victoire** : la grille est vide. Elle est évaluée *avant* la défaite — vider
la grille avec son dernier coup est une réussite.

**Défaite** : plus de coups et des blocs encore là.

**La réserve vaut exactement la solution optimale.** Le but n'est pas de vider
la grille, c'est de trouver la bonne séquence : un coup inutile fait perdre, et
se reprend avec l'annulation. Seuls les dix premiers niveaux accordent une marge
(+2 puis +1), le temps d'apprendre les règles — voir `moveAllowanceForLevel`.

**Le chronomètre ne décide de rien.** Il démarre au premier coup, se suspend
quand l'application passe au second plan, et sert uniquement à battre ses
records. Deux records indépendants par niveau : meilleur temps, meilleur
nombre de coups.

**L'annulation** reprend le dernier déplacement, animé à l'envers, et rend le
coup — un arrêt sur tuile est un déplacement comme un autre. Un refus n'a rien
déplacé : il n'y a rien à reprendre, et il reste dû.

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
│   └── levels/     parseur ASCII, phrases d'apprentissage, dépôt
├── screens/        accueil, jeu, sélection, réglages, debug
├── services/       sauvegarde, haptique, récompenses
└── widgets/        grille jouable, bandeau, boutons, écrans de fin
```

Le moteur, le solveur et le générateur n'importent pas Flutter : ils tournent
dans un test, un isolate ou un outil en ligne de commande.

### La règle, écrite une seule fois

`MoveResolver` porte le glissement, et **le moteur comme le solveur l'appellent**.
Ils explorent le même jeu ; s'ils l'interprétaient chacun de leur côté, la
solution annoncée finirait par diverger de ce que le joueur obtient, et rien ne
le signalerait. La fonction ne connaît ni objets ni état : une grille de
drapeaux (`occupé`, `tuile`), une case, une direction.

### Le solveur

L'état d'une partie, ce sont les **positions** des blocs : un bloc peut être
joué plusieurs fois avant de sortir. La recherche est un **A\*** dont
l'estimation est le nombre de blocs restants — chacun devra sortir au moins une
fois, donc elle ne surestime jamais, et la première solution trouvée est la plus
courte. Un parcours en largeur explorait des centaines de milliers de
configurations avant d'approcher la sortie.

Un bloc ne se déplaçant que dans sa direction, sa coordonnée ne revient jamais
en arrière : l'espace d'états est sans cycle. Les tuiles n'y changent rien,
elles ne font que raccourcir les glissements.

### Le générateur

Génération **par rembobinage** : on part de la grille vide — la victoire — et on
remonte le temps. Deux gestes seulement : faire rentrer un bloc par le bord
(l'inverse d'une sortie), ou reculer un bloc jusqu'à la case d'où il aurait
glissé (l'inverse d'un déplacement).

**Un recul doit être justifié** : sans rien devant lui, le bloc ne se serait
jamais arrêté là. Deux choses peuvent le retenir, et toute la différence est
là. Un **bloc** devant lui, mais le solveur l'évite — il retire l'obstacle
d'abord, et le détour ne devient obligatoire que pris dans un blocage
circulaire. Ou une **tuile d'arrêt**, qui retient sans rien devoir à personne :
le détour est alors inconditionnel, aucun ordre de jeu ne l'évite. C'est ce
second geste qui a levé le plafond du rapport coups / blocs.

**Le générateur propose, le solveur tranche.** Une tuile posée sur le trajet
d'un coup déjà construit ne casse pas la solution : elle l'allonge, le bloc
s'arrêtant là où il passait. Le rembobinage a donc cessé d'être une preuve pour
redevenir ce qu'il est — une bonne façon de proposer des positions. Le prix est
mesuré : dix points de candidats solvables en moins (88 % → 78 %). Le gain
aussi, et il est ailleurs : une tuile qui gêne un autre bloc est forcément
posée sur le chemin de ce bloc ; l'interdire revenait à n'autoriser que les
tuiles qui ne servent à rien. La part d'arrêts porteurs d'une dépendance est
passée de 18 % à 34 %, et le rapport coups / blocs de 1,16 à 1,32 en moyenne.

**Une tuile doit imposer un ordre, sinon elle ne sert à rien.** C'est la leçon
du premier benchmark : posée n'importe où, la tuile allongeait les solutions de
31 % et faisait *baisser* la difficulté de 22 %. Le bloc s'arrêtait sur une case
que personne ne croisait, le joueur tapait une fois de plus, et rien ne changeait
pour personne.

Deux conditions sont donc exigées à la pose. La case doit **couper la route d'un
autre bloc** — une fois posé dessus, le bloc le bloquera, et il faudra jouer ce
voisin avant lui ou le débloquer après. Et le board doit être **presque
complet** : plus tôt, la case ne croise encore personne et le rembobinage ne
sait pas si quelqu'un la croisera. Mesuré : la part d'arrêts porteurs d'une
dépendance passe de 29 % à **67 %** sur cent mille candidats, et le score de
difficulté remonte à parité avec les boards sans tuile (−0,9 %, dans le bruit)
alors qu'il accusait −22 %. Les solutions comptent 34 % de coups par bloc en
plus et cinq fois et demie plus de blocs rejoués, pour la même exigence.

**Les rondes restent rares.** Une ronde de quatre blocs force bien un coup de
plus, mais elle fige quatre cases avant que le rembobinage commence. À un
moment, les dix premiers niveaux étaient *littéralement le même board* : une
ronde occupait tout le budget de blocs, il ne restait rien à construire. Aucune
ronde sous neuf blocs, une ensuite, deux sur les grands boards.

Un bloc a aussi besoin de place **derrière** lui. Sans elle, il ne peut jamais
être reculé, donc jamais retenu : il sortira d'un seul tap quoi qu'il arrive.
Le score de pose en tient compte, et c'est ce qui manquait pour que les tuiles
servent à quelque chose.

**La chaîne.** Un board se noue quand chaque bloc posé vient barrer la route du
précédent : à tout instant, un seul bloc peut encore quitter la grille, et le
dernier recul referme celui-là. La construction refuse donc les gestes qui ne
referment rien (`_chainOnly`), et repart en mode souple si la contrainte a
étouffé le board. Deux conséquences guident le placement : un bloc collé au bord
dans sa direction ne pourra **jamais** être retenu — il est écarté à la pose —
et `closeExits` prolonge la chaîne d'un bloc quand aucun recul ne referme,
parce que la géométrie change et qu'un recul redevient souvent possible ensuite.

Un board tiré au hasard mène presque toujours à une impasse, et le vérifier
coûte une exploration complète : c'est pourquoi on ne tire jamais au hasard.

La génération est **déterministe** : le numéro du niveau suffit à le
reconstruire à l'identique, rien n'est stocké. Le pipeline est
`rembobinage → examens bon marché → solveur → difficulté → aspect → accepter ou
recommencer`.

### La campagne

Le joueur ne reçoit pas des niveaux fabriqués chez lui : il reçoit **la même
campagne que tout le monde**. `assets/levels/campaign_v2.json` associe à chaque
numéro une seed, le nombre de coups optimal et une empreinte. Le board se
reconstruit à l'ouverture ; l'empreinte vérifie qu'il est bien celui qui a été
publié.

Cette fixité n'est pas un détail technique : sans elle, une solution partagée en
vidéo ne veut rien dire, deux joueurs ne peuvent pas se comparer, et un bug ne se
reproduit pas. D'où deux règles :

- `currentGeneratorVersion` ne change jamais sans que le générateur change
  vraiment. Une seed déjà publiée doit rendre le même board pour toujours ; si
  l'algorithme évolue, on publie une version de plus, on ne retouche pas la
  précédente.
- Une association niveau / seed publiée est définitive. Un niveau défectueux se
  désactive (`LevelStatus.disabled`), il ne se remplace pas.

**La progression est liée à la version du générateur.** Un niveau n'est qu'un
numéro ; le puzzle qu'il désigne vient du générateur. Quand celui-ci change, le
niveau 7 n'est plus le même board, et le record de coups qu'on y avait posé
porterait sur un puzzle que personne ne peut plus rejouer. `ProgressService`
inscrit donc `currentGeneratorVersion` à côté de la progression et efface
celle-ci quand les deux ne correspondent plus — une sauvegarde sans version
inscrite datant forcément d'avant, elle s'efface aussi. Les réglages qui ne
dépendent pas des boards, comme l'haptique, survivent. Le joueur est prévenu
une fois à l'accueil : retrouver son compte à zéro sans explication serait pire
que de garder des records faux.

La campagne compte **cent niveaux**. Elle se fabrique avec
`tool/build_campaign.dart` : cent mille candidats sont générés, résolus,
analysés, dédupliqués, puis répartis par tranche — les plus exigeantes servies
en premier, sans quoi elles héritent des restes. Trois fichiers en sortent : le
catalogue, les solutions (développement et QA) et un rapport de métriques par
niveau.

**Il n'y a pas de catalogue pour l'instant.** Le v1 avait été produit par le
générateur v1 ; les règles ayant changé, il ne se reconstruit plus et a été
retiré plutôt que rafistolé — c'est exactement ce que le versionnement veut
dire. Le v2 se construira quand les seuils auront été arrêtés sur les mesures
du benchmark, pas avant. En attendant, le jeu fabrique ses niveaux à la volée.

### Points connus

- **Le plafond de 1,25 n'en était pas tout à fait un, et la tuile l'a fait
  sauter pour de bon.** Sans tuile, un bloc n'est joué deux fois que pris dans
  un blocage circulaire ; le plus petit cycle orthogonal compte quatre blocs
  pour un coup gagné, d'où l'estimation `coups ≤ N + N/4`. Elle tient pour
  l'essentiel — P99,9 à 1,250 sur cinquante-huit mille candidats sans tuile —
  mais **le maximum mesuré est 1,286** : des blocages plus économes que la ronde
  existent, et la démonstration était approximative. Avec tuile, le maximum
  atteint 3,50, et 2,30 si l'on se limite aux candidats de qualité.
- **Un rapport coups / blocs élevé n'est pas une difficulté — c'est même le
  contraire.** Le benchmark est net : `moveComplexity` est **anticorrélée** au
  score de difficulté (r = −0,41) et fortement corrélée aux taps obligatoires
  (r = +0,75 avec `trivialityPenalty`). Ce qui prédit la difficulté, c'est
  l'étroitesse du chemin optimal (r = +0,69) et les dépendances entre blocs
  (r = +0,61). Autrement dit : allonger une solution ne l'approfondit pas.
  C'est pour cela que `meaningfulStopInteractions` ne compte que les arrêts
  changeant ce que les autres blocs peuvent faire, et que `trivialityPenalty`
  retranche le reste. Sans cette distinction, il suffirait d'aligner des tuiles
  pour paraître exigeant.
- **Ce qui reste en retrait, c'est l'étroitesse du chemin optimal** (−69 %
  malgré le placement corrigé), et c'est structurel : un tap imposé par une
  tuile peut souvent se jouer à plusieurs moments sans rien coûter, donc
  plusieurs ordres restent optimaux. Pour contraindre l'ordre, il faudrait que
  l'arrêt rende un autre coup *coûteux*, pas seulement différent. C'est le
  prochain levier — mesuré, pas supposé.
- La difficulté repose donc surtout sur les **décisions** : choix par étape,
  coups qui rallongent la partie, étroitesse du chemin optimal. Avec une réserve
  égale à l'optimal, un seul coup sous-optimal fait perdre — c'est là que se joue
  l'exigence, pas dans la taille du board.
- **Les seuils de difficulté ne sont pas arrêtés.** Les bornes des tranches sont
  volontairement larges en attendant la distribution mesurée : décider de ce
  qu'est un niveau difficile avant de l'avoir compté reviendrait à régler le jeu
  sur une intuition.

### Les premiers niveaux

**Aucun niveau n'est écrit à la main** : les cent boards de la campagne sortent
du générateur, sans exception. Seules les quatre premières phrases sont écrites
— le geste, le glissement, le refus, la tuile — et elles sont attachées au
numéro du niveau, pas à un board (`TutorialHints.forLevel`). Les suivants n'en
ont pas : on apprend en jouant.

## Outils

```bash
dart run tool/build_campaign.dart          # fabrique la campagne officielle
dart run tool/analyze_generated.dart 200   # statistiques par tranche
dart run tool/measure_complexity.dart      # distribution du rapport coups/blocs
dart run tool/measure_decisions.dart       # ce que les niveaux demandent
dart run tool/search_ceiling.dart          # le plafond de l'ancienne mécanique
dart run tool/inspect_level.dart 43        # tout ce qu'on sait d'un niveau
flutter test                               # dont l'épreuve de toute la campagne
```

Le benchmark des tuiles se compile avant de tourner — une heure en mode debug,
une quarantaine de minutes en natif :

```bash
dart compile exe tool/benchmark_stop_tiles.dart -o /tmp/bench
/tmp/bench --seeds 60000
```

Il construit deux populations **sur les mêmes seeds**, sans tuile puis avec, et
en sort quatre fichiers : le détail ligne à ligne, les agrégats, un rapport
lisible et les meilleurs candidats. C'est lui qui doit répondre à la seule
question qui compte ici — est-ce que la tuile approfondit vraiment les puzzles,
ou ne fait-elle qu'allonger les solutions.

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

- Interface en anglais, commentaires et messages de commit en français.
- Le moteur ne connaît ni le temps, ni le score : cela appartient au contrôleur.
- Toute règle de jeu modifiée se répercute dans les tests du même coup.
- Les niveaux s'écrivent en ASCII (`^ v < >` et `#`), lisibles et modifiables.
