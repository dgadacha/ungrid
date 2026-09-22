import '../models/block.dart';
import '../models/direction.dart';

/// Ce qu'un bloc rencontre sur sa trajectoire de sortie.
class PathObstruction {
  const PathObstruction({required this.blockers, required this.wall});

  /// Blocs rencontrés, du plus proche au plus lointain.
  final List<Block> blockers;

  /// `true` si un mur barre la route. Un mur ne bouge jamais : le bloc ne
  /// sortira donc pas de la partie, quoi que fasse le joueur.
  final bool wall;

  bool get isClear => blockers.isEmpty && !wall;
}

/// Détection de collision sur la trajectoire de sortie d'un bloc.
///
/// La règle est unique et tient en une phrase : un bloc sort si aucune case
/// entre lui et le bord, dans sa direction, n'est occupée — ni par un autre
/// bloc, ni par un mur.
class CollisionChecker {
  const CollisionChecker._();

  /// Parcourt la trajectoire de [block] et rapporte ce qu'elle rencontre.
  ///
  /// [occupancy] est indexée `y * columns + x` et contient `null` pour une
  /// case sans bloc ; [walls] marque les cases murées.
  static PathObstruction inspectPath(
    Block block,
    List<Block?> occupancy, {
    required List<bool> walls,
    required int columns,
    required int rows,
  }) {
    final blockers = <Block>[];
    var wall = false;
    final Direction direction = block.direction;
    var x = block.x + direction.dx;
    var y = block.y + direction.dy;

    while (x >= 0 && y >= 0 && x < columns && y < rows) {
      final index = y * columns + x;
      if (walls[index]) wall = true;
      final other = occupancy[index];
      if (other != null) blockers.add(other);
      x += direction.dx;
      y += direction.dy;
    }
    return PathObstruction(blockers: blockers, wall: wall);
  }

  /// `true` si la trajectoire de [block] est entièrement libre.
  static bool canExit(
    Block block,
    List<Block?> occupancy, {
    required List<bool> walls,
    required int columns,
    required int rows,
  }) {
    final Direction direction = block.direction;
    var x = block.x + direction.dx;
    var y = block.y + direction.dy;

    while (x >= 0 && y >= 0 && x < columns && y < rows) {
      final index = y * columns + x;
      if (walls[index] || occupancy[index] != null) return false;
      x += direction.dx;
      y += direction.dy;
    }
    return true;
  }

  /// Nombre de cases à traverser pour quitter complètement la grille.
  static int distanceToExit(
    Block block, {
    required int columns,
    required int rows,
  }) =>
      switch (block.direction) {
        Direction.up => block.y + 1,
        Direction.down => rows - block.y,
        Direction.left => block.x + 1,
        Direction.right => columns - block.x,
      };
}
