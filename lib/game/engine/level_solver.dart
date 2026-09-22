import 'dart:collection';

import '../models/level.dart';
import 'game_engine.dart';
import 'solve_result.dart';

/// Analyse complète d'un niveau : solvabilité, nombre de coups minimal, forme
/// de l'arbre des possibilités.
///
/// Représentation d'état
/// ---------------------
/// Depuis que les blocs glissent, leur position fait partie de l'état : un
/// même bloc peut être joué plusieurs fois avant de sortir. Un état est donc
/// la liste des cases occupées par les blocs encore présents, `-1` marquant
/// ceux qui sont sortis. Les directions et les murs, eux, ne bougent jamais.
///
/// Deux propriétés bornent l'exploration. Un bloc ne se déplace que dans sa
/// direction, donc sa coordonnée ne revient jamais en arrière : l'espace
/// d'états est un graphe sans cycle. Et chaque coup rapproche au moins un bloc
/// du bord. Le parcours en largeur donne donc la solution la plus courte, sans
/// risque de tourner en rond.
class LevelSolver {
  const LevelSolver({this.maxExploredStates = 12000});

  /// Budget d'exploration. Au-delà, l'analyse s'arrête et le dit : mieux vaut
  /// une réponse incomplète annoncée qu'une génération qui s'éternise.
  final int maxExploredStates;

  SolveResult solve(Level level) {
    final board = _Board.of(level);
    final n = level.blocks.length;

    if (n == 0) {
      return const SolveResult(
        solvable: true,
        minimumMoves: 0,
        exploredStates: 1,
        exhaustive: true,
        maxBranchingFactor: 0,
        averageBranchingFactor: 0,
        forcedMoveCount: 0,
        decisionPointCount: 0,
        deadEndCount: 0,
        exampleSolution: [],
      );
    }

    final start = board.initialState();
    final startKey = _key(start);

    // Recherche A*. L'estimation est le nombre de blocs encore en jeu :
    // chacun devra sortir au moins une fois, donc elle ne surestime jamais le
    // reste du chemin, et la première solution trouvée est la plus courte.
    // Un parcours en largeur, lui, explore des centaines de milliers de
    // configurations avant d'approcher la sortie.
    final open = _BucketQueue();
    final cost = <String, int>{startKey: 0};
    final cameFrom = <String, (String parent, int block)>{};
    open.add(board.remainingCount(start), start);

    var deadEnds = 0;
    var exhaustive = true;
    String? goalKey;

    while (!open.isEmpty) {
      if (cost.length > maxExploredStates) {
        exhaustive = false;
        break;
      }

      final state = open.removeFirst();
      final key = _key(state);
      final g = cost[key]!;

      if (board.isCleared(state)) {
        goalKey = key;
        break;
      }

      var moves = 0;
      final occupied = board.occupancyOf(state);
      for (var i = 0; i < n; i++) {
        if (state[i] < 0) continue;
        final next = board.slideWith(state, i, occupied);
        if (next == null) continue; // refus : l'état ne change pas
        moves++;

        final nextKey = _key(next);
        final known = cost[nextKey];
        if (known != null && known <= g + 1) continue;
        cost[nextKey] = g + 1;
        cameFrom[nextKey] = (key, i);
        open.add(g + 1 + board.remainingCount(next), next);
      }
      if (moves == 0) deadEnds++;
    }

    if (goalKey == null) {
      return SolveResult.unsolvable(
        exploredStates: cost.length,
        exhaustive: exhaustive,
        deadEndCount: deadEnds,
      );
    }

    // Remontée du chemin, puis mesure des choix offerts à chaque étape.
    final solution = <String>[];
    final branching = <int>[];
    var cursor = goalKey;
    final path = <int>[];
    while (cursor != startKey) {
      final step = cameFrom[cursor]!;
      path.add(step.$2);
      cursor = step.$1;
    }

    var state = start;
    for (final block in path.reversed) {
      branching.add(board.movableCount(state));
      solution.add(level.blocks[block].id);
      state = board.slide(state, block)!;
    }

    final maxBranching =
        branching.isEmpty ? 0 : branching.reduce((a, b) => a > b ? a : b);
    final average = branching.isEmpty
        ? 0.0
        : branching.fold<int>(0, (a, b) => a + b) / branching.length;

    return SolveResult(
      solvable: true,
      minimumMoves: solution.length,
      exploredStates: cost.length,
      exhaustive: exhaustive,
      maxBranchingFactor: maxBranching,
      averageBranchingFactor: average,
      forcedMoveCount: branching.where((b) => b == 1).length,
      decisionPointCount: branching.where((b) => b >= 2).length,
      deadEndCount: deadEnds,
      exampleSolution: solution,
    );
  }

  /// Vérification rapide, sans métriques : suffit pour rejeter un candidat.
  bool isSolvable(Level level) => solve(level).solvable;

  /// Bloc à jouer maintenant, depuis une configuration donnée.
  ///
  /// L'indice ne se contente pas de proposer un coup possible : il cherche le
  /// premier coup d'une solution. Conseiller un coup qui mène à une impasse
  /// serait pire que ne rien conseiller.
  String? nextBestMove(Level level, List<MoveRecord> playedMoves) {
    final board = _Board.of(level);
    var state = board.initialState();
    for (final move in playedMoves) {
      final index = level.blocks.indexWhere((b) => b.id == move.blockId);
      if (index < 0) continue;
      final next = board.slide(state, index);
      if (next != null) state = next;
    }

    final result = _solveFrom(board, state, level);
    return result.isEmpty ? null : result.first;
  }

  /// Recherche depuis un état quelconque, utilisée par l'indice.
  List<String> _solveFrom(_Board board, List<int> start, Level level) {
    final startKey = _key(start);
    final open = _BucketQueue();
    final cost = <String, int>{startKey: 0};
    final cameFrom = <String, (String, int)>{};
    open.add(board.remainingCount(start), start);
    String? goalKey;

    while (!open.isEmpty && cost.length <= maxExploredStates) {
      final state = open.removeFirst();
      final key = _key(state);
      final g = cost[key]!;

      if (board.isCleared(state)) {
        goalKey = key;
        break;
      }

      final occupied = board.occupancyOf(state);
      for (var i = 0; i < start.length; i++) {
        if (state[i] < 0) continue;
        final next = board.slideWith(state, i, occupied);
        if (next == null) continue;
        final nextKey = _key(next);
        final known = cost[nextKey];
        if (known != null && known <= g + 1) continue;
        cost[nextKey] = g + 1;
        cameFrom[nextKey] = (key, i);
        open.add(g + 1 + board.remainingCount(next), next);
      }
    }

    if (goalKey == null) return const [];

    final moves = <String>[];
    var cursor = goalKey;
    while (cursor != startKey) {
      final step = cameFrom[cursor]!;
      moves.insert(0, level.blocks[step.$2].id);
      cursor = step.$1;
    }
    return moves;
  }

  static String _key(List<int> state) =>
      String.fromCharCodes([for (final cell in state) cell + 1]);
}

/// Vue figée d'un niveau : directions, murs, géométrie.
///
/// Séparée du moteur de jeu pour que l'exploration travaille sur des listes
/// d'entiers plutôt que sur des objets, et reste assez rapide pour valider un
/// niveau à chaque candidat généré.
class _Board {
  _Board({
    required this.columns,
    required this.rows,
    required this.dx,
    required this.dy,
    required this.walls,
    required this.startCells,
  });

  factory _Board.of(Level level) {
    final walls = List<bool>.filled(level.rows * level.columns, false);
    for (final wall in level.walls) {
      walls[wall.y * level.columns + wall.x] = true;
    }
    return _Board(
      columns: level.columns,
      rows: level.rows,
      dx: [for (final b in level.blocks) b.direction.dx],
      dy: [for (final b in level.blocks) b.direction.dy],
      walls: walls,
      startCells: [
        for (final b in level.blocks) b.y * level.columns + b.x,
      ],
    );
  }

  final int columns;
  final int rows;
  final List<int> dx;
  final List<int> dy;
  final List<bool> walls;
  final List<int> startCells;

  List<int> initialState() => List<int>.from(startCells);

  /// Blocs encore en jeu : c'est l'estimation utilisée par la recherche.
  int remainingCount(List<int> state) {
    var count = 0;
    for (final cell in state) {
      if (cell >= 0) count++;
    }
    return count;
  }

  bool isCleared(List<int> state) {
    for (final cell in state) {
      if (cell >= 0) return false;
    }
    return true;
  }

  /// État obtenu en jouant le bloc [index], ou `null` si le coup est refusé.
  List<int>? slide(List<int> state, int index) =>
      slideWith(state, index, occupancyOf(state));

  /// Cases occupées par les blocs d'un état.
  ///
  /// Construite une fois par état développé : la recalculer à chaque coup
  /// testé dominait le coût de l'exploration.
  List<bool> occupancyOf(List<int> state) {
    final occupied = List<bool>.filled(columns * rows, false);
    for (final cell in state) {
      if (cell >= 0) occupied[cell] = true;
    }
    return occupied;
  }

  List<int>? slideWith(List<int> state, int index, List<bool> occupied) {
    final cell = state[index];
    if (cell < 0) return null;

    var x = cell % columns;
    var y = cell ~/ columns;
    final stepX = dx[index];
    final stepY = dy[index];
    var moved = 0;

    while (true) {
      final nx = x + stepX;
      final ny = y + stepY;
      if (nx < 0 || ny < 0 || nx >= columns || ny >= rows) {
        final next = List<int>.from(state);
        next[index] = -1;
        return next;
      }
      final target = ny * columns + nx;
      if (occupied[target] || walls[target]) break;
      x = nx;
      y = ny;
      moved++;
    }

    if (moved == 0) return null;
    final next = List<int>.from(state);
    next[index] = y * columns + x;
    return next;
  }

  /// Nombre de blocs qui bougeraient dans cet état.
  int movableCount(List<int> state) {
    final occupied = occupancyOf(state);
    var count = 0;
    for (var i = 0; i < state.length; i++) {
      if (state[i] < 0) continue;
      if (slideWith(state, i, occupied) != null) count++;
    }
    return count;
  }
}

/// File de priorité à seaux.
///
/// Les priorités de la recherche sont de petits entiers consécutifs : un
/// tableau de files indexé par priorité suffit, et évite le coût d'un tas.
class _BucketQueue {
  final List<Queue<List<int>>> _buckets = [];
  int _cursor = 0;
  int _length = 0;

  bool get isEmpty => _length == 0;

  void add(int priority, List<int> state) {
    while (_buckets.length <= priority) {
      _buckets.add(Queue<List<int>>());
    }
    _buckets[priority].add(state);
    if (priority < _cursor) _cursor = priority;
    _length++;
  }

  List<int> removeFirst() {
    while (_buckets[_cursor].isEmpty) {
      _cursor++;
    }
    _length--;
    return _buckets[_cursor].removeFirst();
  }
}
