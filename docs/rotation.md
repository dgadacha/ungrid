# Tuiles de rotation

Une tuile circulaire arrête le bloc et tourne sa flèche de 90° dans le sens horaire. Elle agit à chaque arrivée, jamais au départ ni sur un coup bloqué. Un bloc initialement dessus conserve sa direction initiale. Les rotations peuvent former des boucles ; undo restaure position et orientation, et les indices résolvent l'état courant.

La campagne principale v3 propose 100 niveaux avec rotations via PLAY. Le lot initial de 10 reste accessible dans Settings → Playtest → ROTATION · 10. Voir [la campagne](campaign-100.md).

## Génération

`RotationGenerator.fromSeed(seed, levelId: ...)` est un mode explicite de génération (règles v1), distinct de `SlideGenerator` v2. Il transforme les arrêts de candidats reproductibles en rotations, puis les résout avec les orientations dans l'état A*. Il rejette les candidats impossibles, hors budget d'exploration, les rotations inutilisées et les solutions fonctionnant encore avec de simples arrêts. Il retourne `null` pour une seed rejetée, jamais un niveau non vérifié.

`dart run tool/build_rotation_pack.dart` produit `build/rotation/rotation_v1.json`. La sélection exige un score de difficulté >= 60, une pénalité de trivialité <= 0,25 et aucune alternative non résolue. Elle choisit dix niveaux parmi trente candidats, triés par score. Le budget de chaque niveau est son minimum exact. Copier le résultat validé dans `assets/levels/rotation_v1.json` pour publier un nouveau lot.

Les grilles sérialisent `rotationTiles: [{x, y}]`. Une case ne peut appartenir à plusieurs familles de tuiles. Les empreintes distinguent les rotations, sans changer les empreintes des anciens niveaux. Les arrêts fragiles et rotations sont compatibles dans le moteur et le solveur ; le lot rotation n'utilise que les rotations.
