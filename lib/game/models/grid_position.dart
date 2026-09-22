import 'direction.dart';

/// Coordonnée immuable dans la grille. Origine en haut à gauche.
class GridPosition {
  const GridPosition(this.x, this.y);

  final int x;
  final int y;

  GridPosition translate(int dx, int dy) => GridPosition(x + dx, y + dy);

  GridPosition step(Direction direction) =>
      GridPosition(x + direction.dx, y + direction.dy);

  bool isInside(int columns, int rows) =>
      x >= 0 && y >= 0 && x < columns && y < rows;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridPosition && other.x == x && other.y == y;

  @override
  int get hashCode => x * 31 + y;

  @override
  String toString() => '($x,$y)';
}
