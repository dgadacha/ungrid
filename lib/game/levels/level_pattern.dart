import '../models/block.dart';
import '../models/difficulty.dart';
import '../models/direction.dart';
import '../models/grid_position.dart';
import '../models/level.dart';

/// Lecture d'un niveau écrit en ASCII.
///
/// Un point ou une espace pour une case vide, `^ v < >` pour un bloc et sa
/// direction, `o` pour une tuile d'arrêt. Chaque chaîne est une ligne de la
/// grille, de haut en bas.
///
/// Un bloc posé sur une tuile s'écrit avec sa direction en capitale —
/// `^ V < >` deviennent `A V L R` serait illisible, on garde donc la flèche
/// et la tuile se lit dans `Level.stopTiles`. Au rendu, la flèche prime.
///
/// Sert aux tests et aux outils : un board se lit et s'écrit alors d'un coup
/// d'oeil.
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
    final stopTiles = <GridPosition>[];

    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      if (row.length != columns) {
        throw ArgumentError(
          'Niveau $id : la ligne $y fait ${row.length} caractères au lieu de $columns',
        );
      }
      for (var x = 0; x < columns; x++) {
        final symbol = row[x];
        if (symbol == '.' || symbol == ' ') continue;
        if (symbol == 'o') {
          stopTiles.add(GridPosition(x, y));
          continue;
        }
        final direction = _symbols[symbol];
        if (direction == null) {
          throw ArgumentError(
            'Niveau $id : symbole inconnu "$symbol" en ($x,$y)',
          );
        }
        blocks.add(
          Block(
            id: 'b${blocks.length}',
            position: GridPosition(x, y),
            direction: direction,
          ),
        );
      }
    }

    return Level(
      id: id,
      rows: rows.length,
      columns: columns,
      blocks: blocks,
      stopTiles: stopTiles,
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
    for (final tile in level.stopTiles) {
      grid[tile.y][tile.x] = 'o';
    }
    for (final block in level.blocks) {
      grid[block.y][block.x] = symbolOf(block.direction);
    }
    return [for (final row in grid) row.join()];
  }
}
