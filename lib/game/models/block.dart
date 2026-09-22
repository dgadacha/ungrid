import 'direction.dart';
import 'grid_position.dart';

/// Nature d'un bloc.
///
/// Le MVP n'utilise que [BlockType.directional]. Les mécaniques futures
/// (rotator, bombe, téléporteur...) viendront s'ajouter ici sans toucher au
/// reste du moteur.
enum BlockType { directional }

/// Un bloc de la grille : une case, une direction de sortie.
class Block {
  const Block({
    required this.id,
    required this.position,
    required this.direction,
    this.type = BlockType.directional,
  });

  final String id;
  final GridPosition position;
  final Direction direction;
  final BlockType type;

  int get x => position.x;
  int get y => position.y;

  Block copyWith({
    String? id,
    GridPosition? position,
    Direction? direction,
    BlockType? type,
  }) =>
      Block(
        id: id ?? this.id,
        position: position ?? this.position,
        direction: direction ?? this.direction,
        type: type ?? this.type,
      );

  Map<String, dynamic> toJson() => {
        'x': position.x,
        'y': position.y,
        'direction': direction.toJson(),
      };

  static Block fromJson(Map<String, dynamic> json, {required String id}) =>
      Block(
        id: id,
        position: GridPosition(json['x'] as int, json['y'] as int),
        direction: Direction.fromJson(json['direction'] as String),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Block &&
          other.id == id &&
          other.position == position &&
          other.direction == direction &&
          other.type == type;

  @override
  int get hashCode => Object.hash(id, position, direction, type);

  @override
  String toString() => 'Block($id ${position.x},${position.y} ${direction.code})';
}
