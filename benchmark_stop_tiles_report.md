# UNGRID — Benchmark des tuiles d'arrêt

Generator version 2 · 60000 seeds · 103199 candidats résolus · 0.0 s

Les deux groupes sont construits **sur les mêmes seeds**, avec le même tirage de forme : à seed égale, le groupe A n'a droit à aucune tuile et le groupe B garde son budget. La comparaison est donc appariée, et l'écart mesuré ne vient que de la mécanique.

## Sans tuile vs avec tuile

| Métrique | Sans tuile (A) | Avec tuile (B) | Écart |
| --- | ---: | ---: | ---: |
| candidats | 58597 | 30194 | |
| optimalMoves | 12.841 | 13.497 | +5.1 % |
| moveComplexity | 1.058 | 1.420 | +34.3 % |
| multiMoveRatio | 0.058 | 0.379 | +559.2 % |
| maxMovesForSingleBlock | 1.522 | 2.267 | +48.9 % |
| decisionScore | 70.112 | 72.062 | +2.8 % |
| optimalPathNarrowness | 0.526 | 0.162 | -69.3 % |
| temptingWrongMoveRatio | 0.711 | 0.474 | -33.3 % |
| dependencyComplexity | 0.836 | 0.637 | -23.7 % |
| trivialityPenalty | 0.139 | 0.272 | +95.3 % |
| exploredStates | 2456.922 | 8498.442 | +245.9 % |
| difficultyScore | 49.425 | 48.998 | -0.9 % |
| visualScore | 73.742 | 73.335 | -0.6 % |

## Le plafond du rapport coups / blocs

| | Sans tuile | Avec tuile |
| --- | ---: | ---: |
| p95 | 1.167 | 1.800 |
| p99 | 1.222 | 2.000 |
| p999 | 1.250 | 2.286 |
| max | 1.286 | 2.444 |
| maxHighQuality | 1.250 | 2.222 |
| candidats de qualité | 36280 | 15670 |

Règle de qualité : `difficultyScore >= 45 && trivialityPenalty <= 0.30 && visualScore >= 50`.

## Distribution du rapport coups / blocs

### Sans tuile

| Tranche | Candidats | % | Difficulté | Décision | Étroitesse | Dépendance | Arrêts | Trivialité |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1.00-1.09 | 41608 | 71.0 | 51.9 | 71.9 | 0.587 | 0.836 | 0.00 | 0.113 |
| 1.10-1.19 | 15292 | 26.1 | 43.7 | 66.3 | 0.385 | 0.836 | 0.00 | 0.200 |
| 1.20-1.29 | 1697 | 2.9 | 40.4 | 60.7 | 0.312 | 0.821 | 0.00 | 0.251 |

### Avec tuile

| Tranche | Candidats | % | Difficulté | Décision | Étroitesse | Dépendance | Arrêts | Trivialité |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1.00-1.09 | 9 | 0.0 | 58.3 | 78.7 | 0.561 | 0.804 | 2.00 | 0.055 |
| 1.10-1.19 | 3135 | 10.4 | 52.3 | 78.0 | 0.247 | 0.751 | 2.03 | 0.148 |
| 1.20-1.29 | 7180 | 23.8 | 48.1 | 73.0 | 0.205 | 0.695 | 2.20 | 0.237 |
| 1.30-1.39 | 5138 | 17.0 | 49.5 | 73.1 | 0.179 | 0.665 | 3.05 | 0.259 |
| 1.40-1.49 | 4175 | 13.8 | 49.8 | 72.3 | 0.144 | 0.624 | 3.75 | 0.286 |
| 1.50-1.59 | 4401 | 14.6 | 48.7 | 70.4 | 0.121 | 0.586 | 4.52 | 0.307 |
| 1.60-1.74 | 3515 | 11.6 | 48.7 | 70.0 | 0.103 | 0.557 | 5.59 | 0.331 |
| 1.75-1.99 | 2042 | 6.8 | 46.9 | 66.7 | 0.077 | 0.515 | 6.48 | 0.368 |
| 2.00-2.49 | 599 | 2.0 | 44.5 | 62.0 | 0.080 | 0.474 | 7.48 | 0.445 |

## Ce que les tuiles servent vraiment

- tuiles par niveau : 1.69
- arrêts le long de la solution : 3.67
- dont porteurs d'une dépendance : 2.41 (66.8 %)
- niveaux avec au moins une tuile inutilisée : 0 (0.0 %)

| Tuiles | Candidats | Coups/bloc | Difficulté | Trivialité |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 14745 | 1.268 | 47.8 | 0.250 |
| 2 | 10581 | 1.494 | 49.8 | 0.281 |
| 3 | 4399 | 1.698 | 50.8 | 0.316 |
| 4 | 466 | 1.920 | 51.3 | 0.365 |
| 5 | 3 | 2.194 | 47.7 | 0.446 |

## Corrélations

Coefficient de Pearson, toutes populations confondues.

| | moveCompl | stopTileC | stopTileI | meaningfu | multiMove | dependenc | optimalPa | decisionS | difficult | trivialit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| moveComplexity | 1.00 | 0.91 | 0.92 | 0.85 | 0.98 | -0.72 | -0.52 | -0.04 | -0.15 | 0.59 |
| stopTileCount | 0.91 | 1.00 | 0.99 | 0.93 | 0.89 | -0.74 | -0.46 | 0.12 | 0.02 | 0.47 |
| stopTileInteractions | 0.92 | 0.99 | 1.00 | 0.95 | 0.89 | -0.72 | -0.45 | 0.13 | 0.04 | 0.46 |
| meaningfulStopInteractions | 0.85 | 0.93 | 0.95 | 1.00 | 0.84 | -0.62 | -0.40 | 0.18 | 0.16 | 0.31 |
| multiMoveRatio | 0.98 | 0.89 | 0.89 | 0.84 | 1.00 | -0.71 | -0.54 | -0.05 | -0.17 | 0.59 |
| dependencyComplexity | -0.72 | -0.74 | -0.72 | -0.62 | -0.71 | 1.00 | 0.59 | 0.09 | 0.37 | -0.49 |
| optimalPathNarrowness | -0.52 | -0.46 | -0.45 | -0.40 | -0.54 | 0.59 | 1.00 | -0.15 | 0.62 | -0.28 |
| decisionScore | -0.04 | 0.12 | 0.13 | 0.18 | -0.05 | 0.09 | -0.15 | 1.00 | 0.55 | -0.61 |
| difficultyScore | -0.15 | 0.02 | 0.04 | 0.16 | -0.17 | 0.37 | 0.62 | 0.55 | 1.00 | -0.55 |
| trivialityPenalty | 0.59 | 0.47 | 0.46 | 0.31 | 0.59 | -0.49 | -0.28 | -0.61 | -0.55 | 1.00 |

## Performance du solveur

| Grille | Candidats | moyenne (ms) | P95 (ms) | P99 (ms) | max (ms) | états explorés (P99) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 4x4 | 14694 | 0.47 | 1.14 | 9.09 | 409.81 | 1158 |
| 5x5 | 38967 | 15.63 | 48.11 | 190.75 | 78758.41 | 31110 |
| 6x6 | 35085 | 94.07 | 155.81 | 336.94 | 1362520.66 | 52236 |
| 7x7 | 14453 | 80.54 | 184.00 | 468.28 | 81611.99 | 54993 |

## La tuile approfondit-elle vraiment les puzzles ?

**La tuile ajoute de la profondeur sans coûter de difficulté.** À seeds égales, les solutions comptent 34.3 % de coups par bloc en plus et 559 % de blocs rejoués en plus, pour un score de difficulté identique (-0.9 %, dans le bruit) et un score de décision de 2.8 %. La mécanique ne creuse donc pas les puzzles par elle-même, mais elle ne les dilue plus : elle donne des positions intermédiaires là où il n'y en avait aucune.

Ce qui reste en retrait est l'étroitesse du chemin optimal (-69.3 %), et c'est structurel : un tap imposé par une tuile peut souvent se jouer à plusieurs moments sans rien coûter, donc plusieurs ordres restent optimaux. C'est le prochain levier, pas un défaut de la mécanique.

66.8 % des arrêts changent ce que les autres blocs peuvent faire. C'est ce que mesure `trivialityPenalty`, en hausse de 95.3 % : sans elle, il suffirait d'aligner des tuiles pour paraître exigeant. Le score de difficulté global varie de -0.9 %.

Le plafond, lui, a bien sauté. Sans tuile, le rapport tient pour l'essentiel sous 1,25 — P99,9 à 1.250 — ce qui confirme l'ordre de grandeur attendu : un bloc n'est joué deux fois que pris dans un blocage circulaire, et le plus petit en compte quatre pour un coup gagné. Mais le maximum mesuré atteint 1.286, donc **1,25 n'était pas un plafond strict** : des blocages plus économes que la ronde existent, et la démonstration était approximative. Avec tuile, le maximum observé est de 2.44, et 2.22 si l'on se limite aux candidats de qualité — c'est ce second chiffre qui doit servir de repère, le maximum brut pouvant n'être qu'un accident.

## Cas limites

**Longs mais faciles** — rapport coups / blocs au-dessus de 1,5 pour une difficulté sous 30 : **586 candidats**. Ce sont des taps obligatoires, pas des décisions : c'est exactement ce que `trivialityPenalty` doit retrancher.

**Courts mais durs** — rapport sous 1,20 pour une difficulté au-dessus de 60 : **12044 candidats**. La difficulté ne se lit donc pas dans la longueur — et il y en a plus que de longs faciles.

Les dix premiers de chaque catégorie sont détaillés dans `benchmark_stop_tiles_summary.json`, les meilleurs candidats dans `benchmark_top_levels.json`.

---

Fichiers : `benchmark_stop_tiles.json` (détail, 103199 lignes), `benchmark_stop_tiles_summary.json` (agrégats), `benchmark_top_levels.json` (candidats exportés).
