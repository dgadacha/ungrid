import '../models/block.dart';
import '../models/direction.dart';
import '../models/grid_position.dart';
import '../models/level.dart';
import '../models/move_result.dart';

/// Un coup joué, de quoi le rejouer à l'envers.
class MoveRecord {
  const MoveRecord({
    required this.blockId,
    required this.from,
    required this.to,
    required this.outcome,
  });

  final String blockId;
  final GridPosition from;

  /// `null` quand le bloc est sorti de la grille.
  final GridPosition? to;

  final MoveOutcome outcome;

  bool get exited => outcome == MoveOutcome.exited;
}

/// Moteur de jeu d'un niveau. Aucune dépendance à Flutter : il peut tourner
/// dans un test, un isolate ou le solveur.
///
/// La règle tient en une phrase : un bloc touché glisse dans la direction de
/// sa flèche aussi loin qu'il peut. Il sort si rien ne l'arrête, s'arrête
/// juste avant l'obstacle sinon, et ne bouge pas du tout quand l'obstacle le
/// touche déjà.
///
/// Les blocs sont donc des obstacles mobiles : déplacer l'un ouvre ou ferme la
/// route des autres, et l'ordre dans lequel on les joue fait tout le puzzle.
///
/// Le moteur ne connaît ni le temps, ni les coups joués, ni le score : il ne
/// gère que l'état du board.
class GameEngine {
  GameEngine(this.level)
      : _occupancy = List<Block?>.filled(level.rows * level.columns, null),
        _walls = List<bool>.filled(level.rows * level.columns, false) {
    for (final wall in level.walls) {
      _walls[wall.y * level.columns + wall.x] = true;
    }
    reset();
  }

  final Level level;

  int get rows => level.rows;
  int get columns => level.columns;

  /// Grille d'occupation, indexée `y * columns + x`.
  final List<Block?> _occupancy;

  /// Cases murées. Fixé une fois pour toutes : un mur ne bouge jamais.
  final List<bool> _walls;

  final Map<String, Block> _remaining = {};

  /// Coups joués, pour l'annulation.
  final List<MoveRecord> _history = [];

  /// Remet le niveau dans son état initial.
  void reset() {
    _occupancy.fillRange(0, _occupancy.length, null);
    _remaining.clear();
    _history.clear();
    for (final block in level.blocks) {
      _remaining[block.id] = block;
      _occupancy[block.y * columns + block.x] = block;
    }
  }

  Iterable<Block> get remainingBlocks => _remaining.values;

  int get remainingCount => _remaining.length;

  bool get isCompleted => _remaining.isEmpty;

  bool get canUndo => _history.isNotEmpty;

  List<MoveRecord> get history => List.unmodifiable(_history);

  Block? blockById(String id) => _remaining[id];

  /// Bloc occupant la cellule, ou `null`.
  Block? blockAt(int x, int y) {
    if (x < 0 || y < 0 || x >= columns || y >= rows) return null;
    return _occupancy[y * columns + x];
  }

  bool isWall(int x, int y) {
    if (x < 0 || y < 0 || x >= columns || y >= rows) return false;
    return _walls[y * columns + x];
  }

  bool _isFree(int x, int y) =>
      _occupancy[y * columns + x] == null && !_walls[y * columns + x];

  /// Nombre de cases libres devant [block], et ce qui l'arrête.
  ///
  /// `distance` vaut le nombre de cases que le bloc peut parcourir ; `exits`
  /// indique qu'il atteindra le bord sans rien rencontrer.
  ({int distance, bool exits, bool wall}) slideRoom(Block block) {
    final Direction direction = block.direction;
    var x = block.x;
    var y = block.y;
    var distance = 0;

    while (true) {
      x += direction.dx;
      y += direction.dy;
      if (x < 0 || y < 0 || x >= columns || y >= rows) {
        return (distance: distance, exits: true, wall: false);
      }
      if (!_isFree(x, y)) {
        return (
          distance: distance,
          exits: false,
          wall: _walls[y * columns + x],
        );
      }
      distance++;
    }
  }

  /// `true` si le bloc peut quitter la grille d'un seul coup.
  bool canExit(String blockId) {
    final block = _remaining[blockId];
    if (block == null) return false;
    return slideRoom(block).exits;
  }

  /// `true` si le bloc a au moins une case devant lui.
  bool canMove(String blockId) {
    final block = _remaining[blockId];
    if (block == null) return false;
    final room = slideRoom(block);
    return room.exits || room.distance > 0;
  }

  /// Tous les blocs qui bougeraient si on les touchait.
  List<Block> movableBlocks() => [
        for (final block in _remaining.values)
          if (canMove(block.id)) block,
      ];

  /// Tous les blocs qui sortiraient d'un seul coup.
  List<Block> exitableBlocks() => [
        for (final block in _remaining.values)
          if (slideRoom(block).exits) block,
      ];

  /// Applique un coup sur [blockId].
  MoveResult tap(String blockId) {
    final block = _remaining[blockId];
    if (block == null) return const MoveResult.ignored();

    final room = slideRoom(block);

    if (room.exits) {
      _lift(block);
      _history.add(MoveRecord(
        blockId: block.id,
        from: block.position,
        to: null,
        outcome: MoveOutcome.exited,
      ));
      return MoveResult(
        outcome: MoveOutcome.exited,
        blockId: block.id,
        from: block.position,
        remainingBlocks: _remaining.length,
      );
    }

    if (room.distance == 0) {
      // L'obstacle touche déjà le bloc : rien à faire, et rien à annuler.
      return MoveResult(
        outcome: MoveOutcome.blocked,
        blockId: block.id,
        from: block.position,
        to: block.position,
        blockedByWall: room.wall,
        remainingBlocks: _remaining.length,
      );
    }

    final destination = GridPosition(
      block.x + block.direction.dx * room.distance,
      block.y + block.direction.dy * room.distance,
    );
    _move(block, destination);
    _history.add(MoveRecord(
      blockId: block.id,
      from: block.position,
      to: destination,
      outcome: MoveOutcome.slid,
    ));

    return MoveResult(
      outcome: MoveOutcome.slid,
      blockId: block.id,
      from: block.position,
      to: destination,
      blockedByWall: room.wall,
      remainingBlocks: _remaining.length,
    );
  }

  void _lift(Block block) {
    _remaining.remove(block.id);
    _occupancy[block.y * columns + block.x] = null;
  }

  void _move(Block block, GridPosition destination) {
    _occupancy[block.y * columns + block.x] = null;
    final moved = block.copyWith(position: destination);
    _remaining[block.id] = moved;
    _occupancy[destination.y * columns + destination.x] = moved;
  }

  /// Annule le dernier coup qui a modifié le plateau.
  ///
  /// Un bloc sorti revient de l'extérieur, un bloc glissé retourne à sa case
  /// de départ. Le coup annulé est rendu au joueur.
  MoveRecord? undo() {
    if (_history.isEmpty) return null;
    final record = _history.removeLast();
    final template = level.blocks.firstWhere((b) => b.id == record.blockId);

    if (record.exited) {
      final restored = template.copyWith(position: record.from);
      _remaining[record.blockId] = restored;
      _occupancy[record.from.y * columns + record.from.x] = restored;
    } else {
      final current = _remaining[record.blockId];
      if (current != null) {
        _occupancy[current.y * columns + current.x] = null;
      }
      final restored = template.copyWith(position: record.from);
      _remaining[record.blockId] = restored;
      _occupancy[record.from.y * columns + record.from.x] = restored;
    }
    return record;
  }

  /// Rejoue une suite de coups depuis l'état initial.
  void restore(List<MoveRecord> moves) {
    reset();
    for (final move in moves) {
      tap(move.blockId);
    }
  }
}
