# Difficulté de planification

## Pourquoi la campagne v3 était surestimée

Le niveau 81 a été résolu par le joueur en 14 secondes. Sa solution publiée compte 12 coups pour 8 blocs, avec les séquences `b0,b0`, `b1,b1`, puis `b4,b4`. Un seul coup revient à un bloc déjà joué après en avoir joué un autre. Le score 73,9 récompensait les choix et interactions sans distinguer suffisamment ces séquences locales d'un ordre à planifier.

## Nouveau filtre

`PlanningDifficulty` mesure les retours différés sur la solution optimale fournie : un bloc est repris après un autre bloc, au lieu d'être immédiatement joué jusqu'à sa sortie. La sélection exige au moins trois retours différés et au moins 16 coups optimaux. Les niveaux 81 à 100 en exigent au moins quatre dans la solution de référence. Le classement privilégie ce compteur, puis le score existant.

Elle teste aussi 24 parcours déterministes qui privilégient les sorties immédiates, puis choisissent un déplacement jouable. Au plus un parcours peut réussir dans le budget. Cette épreuve est un indicateur complémentaire : le niveau 81 v3 échoue déjà à ces parcours, donc elle ne suffit pas seule à prédire la difficulté humaine.

Les contrôles précédents restent appliqués : toutes les rotations utilisées, solution affectée par la rotation, aucune alternative non résolue, score >= 60, trivialité <= 0,20, étroitesse >= 0,35, mauvais choix >= 0,50 et dépendances >= 0,65.

## Génération

`dart run tool/build_planning_campaign.dart` crée des variantes déterministes des grilles v2 et v3 : déplacement ou ajout d'une rotation (trois au maximum), et modification d’une ou deux directions. Chaque variante est résolue de nouveau ; son ancien budget n'est jamais réutilisé. Le script exporte 100 grilles distinctes dans `build/planning_campaign/` avec leurs solutions et mesures.

Les compteurs portent sur une solution optimale, pas une preuve que toutes les solutions exigent autant de retours différés. Ces filtres sont des critères de sélection plus exigeants, pas une garantie de durée humaine. Le retour du joueur reste nécessaire pour calibrer le niveau expert.

Le script accepte une plage `début fin`, sauvegarde les candidats en JSONL dans `build/planning_campaign/`, puis `--merge fichier1.jsonl fichier2.jsonl ...` sélectionne et exporte le catalogue après déduplication.
