import 'dart:typed_data';

import '../models/block.dart';
import '../models/grid_position.dart';
import '../models/level.dart';
import '../models/move_result.dart';
import 'move_resolver.dart';

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

  /// Un arrêt sur tuile est un déplacement comme un autre : il s'annule.
  bool get stopped => outcome == MoveOutcome.stopped;
}

/// Moteur de jeu d'un niveau. Aucune dépendance à Flutter : il peut tourner
/// dans un test, un isolate ou le solveur.
///
/// La règle tient en une phrase : un bloc touché glisse dans la direction de
/// sa flèche aussi loin qu'il peut. Il sort si rien ne l'arrête, se pose sur
/// la tuile d'arrêt qu'il rencontre, s'arrête juste avant un bloc, et ne bouge
/// pas du tout quand un bloc le touche déjà.
///
/// Les blocs sont donc des obstacles mobiles : déplacer l'un ouvre ou ferme la
/// route des autres, et l'ordre dans lequel on les joue fait tout le puzzle.
/// Les tuiles, elles, ne bougent pas : ce sont les points fixes sur lesquels
/// la position se reconstruit.
///
/// Le moteur ne connaît ni le temps, ni les coups joués, ni le score : il ne
/// gère que l'état du board. Il ne décide pas non plus de la règle du
/// glissement, qu'il partage avec le solveur ([MoveResolver]).
class GameEngine {
  GameEngine(this.level)
      : _occupancy = List<Block?>.filled(level.rows * level.columns, null),
        _cells = Uint8List(level.rows * level.columns),
        _stops = level.stopMask() {
    reset();
  }

  final Level level;

  int get rows => level.rows;
  int get columns => level.columns;

  /// Grille d'occupation, indexée `y * columns + x`.
  final List<Block?> _occupancy;

  /// La même grille vue par le résolveur : occupation et tuiles d'arrêt.
  final Uint8List _cells;

  /// Les tuiles seules, pour repartir d'une grille propre.
  final Uint8List _stops;

  final Map<String, Block> _remaining = {};

  /// Coups joués, pour l'annulation.
  final List<MoveRecord> _history = [];

  /// Remet le niveau dans son état initial.
  void reset() {
    _occupancy.fillRange(0, _occupancy.length, null);
    _cells.setAll(0, _stops);
    _remaining.clear();
    _history.clear();
    for (final block in level.blocks) {
      _remaining[block.id] = block;
      _occupy(block);
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

  bool hasStopTileAt(int x, int y) {
    if (x < 0 || y < 0 || x >= columns || y >= rows) return false;
    return _stops[y * columns + x] & cellStopTile != 0;
  }

  /// Ce que donnerait un tap sur ce bloc, sans rien changer au plateau.
  SlideOutcome slideRoom(Block block) => MoveResolver.resolve(
        cell: block.y * columns + block.x,
        stepX: block.direction.dx,
        stepY: block.direction.dy,
        columns: columns,
        rows: rows,
        cells: _cells,
      );

  /// `true` si le bloc peut quitter la grille d'un seul coup.
  bool canExit(String blockId) {
    final block = _remaining[blockId];
    if (block == null) return false;
    return slideRoom(block).outcome == MoveOutcome.exited;
  }

  /// `true` si toucher le bloc changerait quelque chose.
  bool canMove(String blockId) {
    final block = _remaining[blockId];
    if (block == null) return false;
    return slideRoom(block).outcome != MoveOutcome.blocked;
  }

  /// Tous les blocs qui bougeraient si on les touchait.
  List<Block> movableBlocks() => [
        for (final block in _remaining.values)
          if (canMove(block.id)) block,
      ];

  /// Tous les blocs qui sortiraient d'un seul coup.
  List<Block> exitableBlocks() => [
        for (final block in _remaining.values)
          if (slideRoom(block).outcome == MoveOutcome.exited) block,
      ];

  /// Applique un coup sur [blockId].
  MoveResult tap(String blockId) {
    final block = _remaining[blockId];
    if (block == null) return const MoveResult.ignored();

    final room = slideRoom(block);

    switch (room.outcome) {
      case MoveOutcome.exited:
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

      case MoveOutcome.blocked:
        // L'obstacle touche déjà le bloc : rien à faire, et rien à annuler.
        return MoveResult(
          outcome: MoveOutcome.blocked,
          blockId: block.id,
          from: block.position,
          to: block.position,
          remainingBlocks: _remaining.length,
        );

      case MoveOutcome.slid:
      case MoveOutcome.stopped:
        final destination = GridPosition(
          room.cell % columns,
          room.cell ~/ columns,
        );
        _move(block, destination);
        _history.add(MoveRecord(
          blockId: block.id,
          from: block.position,
          to: destination,
          outcome: room.outcome,
        ));
        return MoveResult(
          outcome: room.outcome,
          blockId: block.id,
          from: block.position,
          to: destination,
          remainingBlocks: _remaining.length,
        );

      case MoveOutcome.ignored:
        return const MoveResult.ignored();
    }
  }

  void _occupy(Block block) {
    final cell = block.y * columns + block.x;
    _occupancy[cell] = block;
    _cells[cell] |= cellOccupied;
  }

  void _vacate(int cell) {
    _occupancy[cell] = null;
    _cells[cell] &= ~cellOccupied;
  }

  void _lift(Block block) {
    _remaining.remove(block.id);
    _vacate(block.y * columns + block.x);
  }

  void _move(Block block, GridPosition destination) {
    _vacate(block.y * columns + block.x);
    final moved = block.copyWith(position: destination);
    _remaining[block.id] = moved;
    _occupy(moved);
  }

  /// Annule le dernier coup qui a modifié le plateau.
  ///
  /// Un bloc sorti revient de l'extérieur, un bloc déplacé retourne à sa case
  /// de départ. Le coup annulé est rendu au joueur.
  MoveRecord? undo() {
    if (_history.isEmpty) return null;
    final record = _history.removeLast();
    final template = level.blocks.firstWhere((b) => b.id == record.blockId);

    if (!record.exited) {
      final current = _remaining[record.blockId];
      if (current != null) _vacate(current.y * columns + current.x);
    }

    final restored = template.copyWith(position: record.from);
    _remaining[record.blockId] = restored;
    _occupy(restored);
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
