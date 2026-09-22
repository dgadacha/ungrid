import '../models/block.dart';
import '../models/difficulty.dart';
import '../models/direction.dart';
import '../models/grid_position.dart';
import '../models/level.dart';

/// Lecture d'un niveau écrit en ASCII.
///
/// Un point ou une espace pour une case vide, `^ v < >` pour un bloc et sa
/// direction, `#` pour un mur. Chaque chaîne est une ligne de la grille, de
/// haut en bas.
class LevelPattern {
  const LevelPattern._();

  static const Map<String, Direction> _symbols = {
    '^': Direction.up,
    'v': Direction.down,
    '<': Direction.left,
    '>': Direction.right,
  };

  static String symbolOf(Direction direction) => switch (direction) {
        Direction.up => '^',
        Direction.down => 'v',
        Direction.left => '<',
        Direction.right => '>',
      };

  static const String wallSymbol = '#';

  static Level parse(
    List<String> rows, {
    required int id,
    Difficulty difficulty = Difficulty.easy,
  }) {
    if (rows.isEmpty) {
      throw ArgumentError('Niveau $id : grille vide');
    }
    final columns = rows.first.length;
    final blocks = <Block>[];
    final walls = <GridPosition>[];

    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      if (row.length != columns) {
        throw ArgumentError(
            'Niveau $id : la ligne $y fait ${row.length} caractères au lieu de $columns');
      }
      for (var x = 0; x < columns; x++) {
        final symbol = row[x];
        if (symbol == '.' || symbol == ' ') continue;
        if (symbol == wallSymbol) {
          walls.add(GridPosition(x, y));
          continue;
        }
        final direction = _symbols[symbol];
        if (direction == null) {
          throw ArgumentError('Niveau $id : symbole inconnu "$symbol" en ($x,$y)');
        }
        blocks.add(Block(
          id: 'b${blocks.length}',
          position: GridPosition(x, y),
          direction: direction,
        ));
      }
    }

    return Level(
      id: id,
      rows: rows.length,
      columns: columns,
      blocks: blocks,
      walls: walls,
      // Chaque bloc sort exactement une fois : le minimum de coups réussis
      // est donc le nombre de blocs.
      // Valeur provisoire : le solveur la corrige, un bloc pouvant demander
      // plusieurs coups.
      optimalMoves: blocks.length,
      difficulty: difficulty,
    );
  }

  /// Rendu ASCII d'un niveau, utile au debug et aux messages d'erreur.
  static List<String> render(Level level) {
    final grid = List.generate(
      level.rows,
      (_) => List.filled(level.columns, '.'),
      growable: false,
    );
    for (final wall in level.walls) {
      grid[wall.y][wall.x] = wallSymbol;
    }
    for (final block in level.blocks) {
      grid[block.y][block.x] = symbolOf(block.direction);
    }
    return [for (final row in grid) row.join()];
  }
}
