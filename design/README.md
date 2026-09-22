# Fichiers de travail

Ces images ne sont pas embarquées dans l'application. Elles servent à
fabriquer celles qui le sont.

| Fichier | Rôle |
| --- | --- |
| `block.png` | Bloc en relief, première piste visuelle. Conservé pour mémoire : le jeu dessine ses blocs à plat, sans texture. |
| `icon.png` | Icône carrée du jeu. Source de `icon_ios.png` et `icon_android_foreground.png`. |
| `icon_ios.png` | Icône aplatie, sans transparence, débordant jusqu'au bord. |
| `icon_android_foreground.png` | Premier plan de l'icône adaptative, dans la zone sûre. |

Les blocs du jeu ne sont pas des images : ils sont tracés par
`lib/game/painters/block_painter.dart`. Un aplat de couleur, des coins
arrondis, une flèche vectorielle. Le rendu reste net quelle que soit la taille
de la grille, se teinte librement et pivote sans qu'un éclairage vienne
trahir la rotation.

Après modification de `icon.png` :

```bash
python3 design/make_icons.py && dart run flutter_launcher_icons
```

Le script a besoin de Pillow.
