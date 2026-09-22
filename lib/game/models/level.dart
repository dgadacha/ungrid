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
    this.walls = const [],
    this.difficulty = Difficulty.easy,
    this.seed,
    int? moveAllowance,
  }) : moveAllowance = moveAllowance ?? moveAllowanceFor(difficulty);

  final int id;
  final int rows;
  final int columns;
  final List<Block> blocks;

  /// Obstacles permanents. Ils ne bougent pas, ne sortent pas, ne se touchent
  /// pas : ils barrent la route, et c'est tout. Ils ne comptent donc pas dans
  /// la condition de victoire, qui ne regarde que les blocs.
  final List<GridPosition> walls;

  /// Nombre minimal de coups pour vider la grille, calculé par le solveur.
  /// Chaque bloc sortant exactement une fois, c'est le nombre de blocs.
  final int optimalMoves;

  /// Coups d'erreur tolérés au-delà de [optimalMoves].
  final int moveAllowance;

  /// Coups dont dispose le joueur. Au-delà, la partie est perdue.
  int get moveLimit => optimalMoves + moveAllowance;

  final Difficulty difficulty;

  /// Seed de génération, `null` pour les niveaux écrits à la main.
  final int? seed;

  bool get isGenerated => seed != null;

  int get cellCount => rows * columns;

  double get density => blocks.length / cellCount;

  /// Part de la grille occupée, murs compris : c'est elle qui décide de
  /// l'encombrement visuel.
  double get occupancy => (blocks.length + walls.length) / cellCount;

  Level copyWith({
    int? id,
    List<Block>? blocks,
    int? optimalMoves,
    Difficulty? difficulty,
    int? seed,
    int? moveAllowance,
  }) =>
      Level(
        id: id ?? this.id,
        rows: rows,
        columns: columns,
        blocks: blocks ?? this.blocks,
        walls: walls,
        optimalMoves: optimalMoves ?? this.optimalMoves,
        difficulty: difficulty ?? this.difficulty,
        seed: seed ?? this.seed,
        moveAllowance: moveAllowance,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'rows': rows,
        'columns': columns,
        'moveAllowance': moveAllowance,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'walls': walls.map((w) => {'x': w.x, 'y': w.y}).toList(),
      };

  static Level fromJson(Map<String, dynamic> json, {int optimalMoves = 0}) {
    final rawBlocks = (json['blocks'] as List).cast<Map<String, dynamic>>();
    final rawWalls =
        (json['walls'] as List? ?? const []).cast<Map<String, dynamic>>();
    return Level(
      id: json['id'] as int,
      rows: json['rows'] as int,
      columns: json['columns'] as int,
      blocks: [
        for (var i = 0; i < rawBlocks.length; i++)
          Block.fromJson(rawBlocks[i], id: 'b$i'),
      ],
      optimalMoves:
          json['optimalMoves'] as int? ?? (optimalMoves == 0 ? rawBlocks.length : optimalMoves),
      walls: [
        for (final wall in rawWalls)
          GridPosition(wall['x'] as int, wall['y'] as int),
      ],
      moveAllowance: json['moveAllowance'] as int?,
    );
  }

  /// Vérifie l'intégrité structurelle : coordonnées valides, pas de
  /// superposition, identifiants uniques.
  bool get isStructurallyValid {
    final seen = <int>{};
    final ids = <String>{};
    for (final wall in walls) {
      if (!wall.isInside(columns, rows)) return false;
      if (!seen.add(wall.y * columns + wall.x)) return false;
    }
    for (final block in blocks) {
      if (!block.position.isInside(columns, rows)) return false;
      if (!seen.add(block.y * columns + block.x)) return false;
      if (!ids.add(block.id)) return false;
    }
    return blocks.isNotEmpty;
  }

  @override
  String toString() =>
      'Level($id ${columns}x$rows, ${blocks.length} blocs, $moveLimit coups)';
}
