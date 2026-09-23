import 'dart:typed_data';

import 'block.dart';
import 'difficulty.dart';
import 'grid_position.dart';

/// Un niveau : une grille, des blocs, et le nombre de coups optimal.
class Level {
  Level({
    required this.id,
    required this.rows,
    required this.columns,
    required this.blocks,
    required this.optimalMoves,
    this.stopTiles = const [],
    this.difficulty = Difficulty.easy,
    this.seed,
  });

  final int id;
  final int rows;
  final int columns;
  final List<Block> blocks;

  /// Cases qui retiennent un bloc entrant dessus.
  ///
  /// Elles ne bougent jamais, ne se touchent pas, ne comptent pas dans la
  /// victoire : ce sont des points d'arrêt, pas des obstacles. Un bloc peut
  /// démarrer sur l'une d'elles sans être retenu.
  final List<GridPosition> stopTiles;

  /// Nombre minimal de coups pour vider la grille, calculé par le solveur.
  ///
  /// Un bloc peut devoir être joué plusieurs fois : ce n'est donc pas le
  /// nombre de blocs.
  final int optimalMoves;

  /// Coups dont dispose le joueur : exactement la solution optimale.
  ///
  /// Le but n'est pas de vider la grille, c'est de trouver la bonne séquence.
  /// Une erreur ne se paie pas en marge, elle se reprend — d'où l'importance
  /// de l'annulation.
  int get moveLimit => optimalMoves;

  final Difficulty difficulty;

  /// Seed de génération, `null` pour les niveaux écrits à la main.
  final int? seed;

  bool get isGenerated => seed != null;

  int get cellCount => rows * columns;

  /// Part de la grille occupée. C'est elle qui décide de l'encombrement
  /// visuel, et de ce qui peut encore glisser.
  double get density => blocks.length / cellCount;

  double get occupancy => density;

  Level copyWith({
    int? id,
    List<Block>? blocks,
    List<GridPosition>? stopTiles,
    int? optimalMoves,
    Difficulty? difficulty,
    int? seed,
  }) =>
      Level(
        id: id ?? this.id,
        rows: rows,
        columns: columns,
        blocks: blocks ?? this.blocks,
        stopTiles: stopTiles ?? this.stopTiles,
        optimalMoves: optimalMoves ?? this.optimalMoves,
        difficulty: difficulty ?? this.difficulty,
        seed: seed ?? this.seed,
      );

  /// Grille des tuiles d'arrêt, prête pour le résolveur.
  Uint8List stopMask() {
    final mask = Uint8List(cellCount);
    for (final tile in stopTiles) {
      mask[tile.y * columns + tile.x] = 2;
    }
    return mask;
  }

  bool hasStopTileAt(int x, int y) {
    for (final tile in stopTiles) {
      if (tile.x == x && tile.y == y) return true;
    }
    return false;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rows': rows,
        'columns': columns,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        if (stopTiles.isNotEmpty)
          'stopTiles': [
            for (final tile in stopTiles) {'x': tile.x, 'y': tile.y},
          ],
      };

  static Level fromJson(Map<String, dynamic> json, {int optimalMoves = 0}) {
    final rawBlocks = (json['blocks'] as List).cast<Map<String, dynamic>>();
    return Level(
      id: json['id'] as int,
      rows: json['rows'] as int,
      columns: json['columns'] as int,
      blocks: [
        for (var i = 0; i < rawBlocks.length; i++)
          Block.fromJson(rawBlocks[i], id: 'b$i'),
      ],
      stopTiles: [
        for (final tile in (json['stopTiles'] as List? ?? const []).cast<Map>())
          GridPosition(tile['x'] as int, tile['y'] as int),
      ],
      optimalMoves:
          json['optimalMoves'] as int? ?? (optimalMoves == 0 ? rawBlocks.length : optimalMoves),
    );
  }

  /// Vérifie l'intégrité structurelle : coordonnées valides, pas de
  /// superposition, identifiants uniques.
  bool get isStructurallyValid {
    final seen = <int>{};
    final ids = <String>{};
    for (final block in blocks) {
      if (!block.position.isInside(columns, rows)) return false;
      if (!seen.add(block.y * columns + block.x)) return false;
      if (!ids.add(block.id)) return false;
    }
    final tiles = <int>{};
    for (final tile in stopTiles) {
      if (!tile.isInside(columns, rows)) return false;
      if (!tiles.add(tile.y * columns + tile.x)) return false;
    }
    return blocks.isNotEmpty;
  }

  @override
  String toString() =>
      'Level($id ${columns}x$rows, ${blocks.length} blocs, $moveLimit coups)';
}
