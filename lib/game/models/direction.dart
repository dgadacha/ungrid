/// Les quatre directions de sortie possibles d'un bloc.
///
/// Le repère de la grille a son origine en haut à gauche :
/// `x` augmente vers la droite, `y` augmente vers le bas.
enum Direction {
  up(dx: 0, dy: -1, code: 'U'),
  down(dx: 0, dy: 1, code: 'D'),
  left(dx: -1, dy: 0, code: 'L'),
  right(dx: 1, dy: 0, code: 'R');

  const Direction({required this.dx, required this.dy, required this.code});

  /// Déplacement horizontal d'un pas dans cette direction.
  final int dx;

  /// Déplacement vertical d'un pas dans cette direction.
  final int dy;

  /// Lettre utilisée pour la sérialisation et le hash d'état.
  final String code;

  bool get isHorizontal => dy == 0;
  bool get isVertical => dx == 0;

  Direction get clockwise => switch (this) {
    Direction.up => Direction.right,
    Direction.right => Direction.down,
    Direction.down => Direction.left,
    Direction.left => Direction.up,
  };

  Direction get opposite => switch (this) {
    Direction.up => Direction.down,
    Direction.down => Direction.up,
    Direction.left => Direction.right,
    Direction.right => Direction.left,
  };

  /// Angle de rotation (radians) à appliquer à une flèche pointant vers la
  /// droite pour qu'elle pointe dans cette direction.
  double get angle => switch (this) {
    Direction.right => 0,
    Direction.down => 1.5707963267948966,
    Direction.left => 3.141592653589793,
    Direction.up => 4.71238898038469,
  };

  static Direction fromJson(String value) => switch (value.toLowerCase()) {
    'up' || 'u' => Direction.up,
    'down' || 'd' => Direction.down,
    'left' || 'l' => Direction.left,
    'right' || 'r' => Direction.right,
    _ => throw ArgumentError('Direction inconnue: $value'),
  };

  String toJson() => name;
}
