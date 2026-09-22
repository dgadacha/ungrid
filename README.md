# UNGRID

Puzzle mobile : videz la grille avant de manquer de coups.

Touchez un bloc, il glisse dans la direction de sa flèche jusqu'à l'obstacle
suivant — ou hors de la grille. Chaque tap compte, même celui qui ne déplace
rien.

## Démarrer

```bash
flutter run
```

Les niveaux ne sont pas stockés : ils sont reconstruits à partir de leur
numéro. Les vingt premiers sont écrits à la main, les suivants sont fabriqués
et validés à la volée.

## Tests

```bash
flutter test
```

L'épreuve de fond génère mille niveaux et vérifie qu'ils sont tous jouables,
reproductibles et fabriqués assez vite pour que personne ne s'en aperçoive.

Le détail des règles et de l'architecture est dans [CLAUDE.md](CLAUDE.md).
