import 'dart:collection';
import 'dart:typed_data';

import '../models/level.dart';
import '../models/move_result.dart';
import 'game_engine.dart';
import 'move_resolver.dart';
import 'solve_result.dart';

/// Analyse complète d'un niveau : solvabilité, nombre de coups minimal, forme
/// de l'arbre des possibilités.
///
/// Représentation d'état
/// ---------------------
/// Depuis que les blocs glissent, leur position fait partie de l'état : un
/// même bloc peut être joué plusieurs fois avant de sortir. Un état est donc
/// la liste des cases occupées par les blocs encore présents, `-1` marquant
/// ceux qui sont sortis. Les directions et les tuiles d'arrêt, elles, ne
/// bougent jamais : elles sont portées par le board, pas par l'état.
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
      final cells = board.cellsOf(state);
      for (var i = 0; i < n; i++) {
        if (state[i] < 0) continue;
        final next = board.slideWith(state, i, cells);
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

  /// Rejoue une solution et éprouve, à chaque étape, les coups écartés.
  ///
  /// C'est ce qui distingue un long couloir d'un vrai puzzle : combien de
  /// coups s'offraient, combien menaient à une partie plus longue, combien la
  /// condamnaient, et combien la laissaient encore gagnable au plus court.
  /// Chaque alternative est résolue à son tour, d'où le coût — à réserver aux
  /// candidats déjà retenus.
  SolutionWalk walkSolution(Level level, List<String> moves) {
    final board = _Board.of(level);
    var state = board.initialState();

    final choices = <int>[];
    final optimalChoices = <int>[];
    var wrongMoves = 0;
    var deadEnds = 0;
    var stopInteractions = 0;
    var meaningfulStops = 0;
    var dependencyMoves = 0;
    var unresolved = 0;
    final usedStopTiles = <int>{};

    // Ce qu'il reste à jouer en suivant la solution, à chaque étape.
    var remaining = moves.length;

    for (final move in moves) {
      final index = level.blocks.indexWhere((b) => b.id == move);
      if (index < 0) break;

      final cells = board.cellsOf(state);
      var available = 0;
      var optimal = 0;

      for (var i = 0; i < state.length; i++) {
        if (state[i] < 0) continue;
        final next = board.slideWith(state, i, cells);
        if (next == null) continue; // un refus ne décide de rien
        available++;

        // Ce que coûte l'autre chemin : la partie est-elle perdue, rallongée,
        // ou aussi bonne ? Une réponse hors budget n'est aucune des trois, et
        // ne se compte nulle part — la prendre pour une impasse créditerait
        // les grands boards de pièges qui n'existent pas.
        final cost = _distanceFrom(board, next);
        if (cost == _unknown) {
          unresolved++;
        } else if (cost == _unreachable) {
          if (i != index) deadEnds++;
        } else if (cost > remaining - 1) {
          if (i != index) wrongMoves++;
        } else {
          optimal++;
        }
      }

      choices.add(available);
      optimalChoices.add(optimal);

      // Ce que le coup joué change pour les autres : c'est là que se noue la
      // dépendance, et c'est ce qui sépare un arrêt utile d'un tap forcé.
      final before = board.prospects(state, cells, skip: index);
      final next = board.slideWith(state, index, cells);
      if (next == null) break;
      final landed = next[index];
      final after = board.prospects(next, board.cellsOf(next), skip: index);
      final changed = !_sameProspects(before, after);
      if (changed) dependencyMoves++;

      if (landed >= 0 && board.isStopTile(landed)) {
        stopInteractions++;
        usedStopTiles.add(landed);
        if (changed) meaningfulStops++;
      }

      state = next;
      remaining--;
    }

    return SolutionWalk(
      choices: choices,
      optimalChoices: optimalChoices,
      wrongMoves: wrongMoves,
      deadEnds: deadEnds,
      stopInteractions: stopInteractions,
      meaningfulStopInteractions: meaningfulStops,
      dependencyMoves: dependencyMoves,
      usedStopTiles: usedStopTiles.length,
      unresolvedAlternatives: unresolved,
    );
  }

  static bool _sameProspects(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Coups nécessaires pour vider la grille depuis cet état.
  ///
  /// Renvoie [_unreachable] quand la position est réellement perdue, et
  /// [_unknown] quand l'exploration a manqué de budget. Les confondre
  /// reviendrait à compter comme piège tout état simplement trop gros à
  /// analyser, et à créditer les grands boards de pièges imaginaires.
  static const int _unreachable = -1;
  static const int _unknown = -2;

  int _distanceFrom(_Board board, List<int> start) {
    final startKey = _key(start);
    final open = _BucketQueue();
    final cost = <String, int>{startKey: 0};
    open.add(board.remainingCount(start), start);

    while (!open.isEmpty) {
      if (cost.length > maxExploredStates) return _unknown;
      final state = open.removeFirst();
      final key = _key(state);
      final g = cost[key]!;
      if (board.isCleared(state)) return g;

      final cells = board.cellsOf(state);
      for (var i = 0; i < state.length; i++) {
        if (state[i] < 0) continue;
        final next = board.slideWith(state, i, cells);
        if (next == null) continue;
        final nextKey = _key(next);
        final known = cost[nextKey];
        if (known != null && known <= g + 1) continue;
        cost[nextKey] = g + 1;
        open.add(g + 1 + board.remainingCount(next), next);
      }
    }
    return _unreachable;
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

      final cells = board.cellsOf(state);
      for (var i = 0; i < start.length; i++) {
        if (state[i] < 0) continue;
        final next = board.slideWith(state, i, cells);
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

/// Vue figée d'un niveau : directions, tuiles d'arrêt, géométrie.
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
    required this.startCells,
    required this.stopMask,
  });

  factory _Board.of(Level level) {
    return _Board(
      columns: level.columns,
      rows: level.rows,
      dx: [for (final b in level.blocks) b.direction.dx],
      dy: [for (final b in level.blocks) b.direction.dy],
      startCells: [
        for (final b in level.blocks) b.y * level.columns + b.x,
      ],
      stopMask: level.stopMask(),
    );
  }

  final int columns;
  final int rows;
  final List<int> dx;
  final List<int> dy;
  final List<int> startCells;

  /// Grille des tuiles d'arrêt : elle ne change jamais, on la recopie.
  final Uint8List stopMask;

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
      slideWith(state, index, cellsOf(state));

  /// La grille telle que le résolveur la lit : tuiles d'arrêt du board, plus
  /// les blocs de cet état.
  ///
  /// Construite une fois par état développé : la recalculer à chaque coup
  /// testé dominait le coût de l'exploration.
  Uint8List cellsOf(List<int> state) {
    final cells = Uint8List.fromList(stopMask);
    for (final cell in state) {
      if (cell >= 0) cells[cell] |= cellOccupied;
    }
    return cells;
  }

  List<int>? slideWith(List<int> state, int index, Uint8List cells) {
    final cell = state[index];
    if (cell < 0) return null;

    final move = MoveResolver.resolve(
      cell: cell,
      stepX: dx[index],
      stepY: dy[index],
      columns: columns,
      rows: rows,
      cells: cells,
    );
    if (move.outcome == MoveOutcome.blocked) return null;

    final next = List<int>.from(state);
    next[index] = move.cell;
    return next;
  }

  bool isStopTile(int cell) => stopMask[cell] & cellStopTile != 0;

  /// Ce que chaque bloc ferait si on le touchait maintenant.
  ///
  /// Sert à mesurer l'effet d'un coup sur les autres : deux relevés qui
  /// diffèrent signifient que le coup a ouvert ou fermé une route, donc qu'il
  /// compte pour quelqu'un d'autre que celui qu'on a bougé.
  List<int> prospects(List<int> state, Uint8List cells, {required int skip}) {
    final out = <int>[];
    for (var i = 0; i < state.length; i++) {
      if (i == skip || state[i] < 0) continue;
      final next = slideWith(state, i, cells);
      out.add(next == null ? -2 : next[i]);
    }
    return out;
  }

  /// Nombre de blocs qui bougeraient dans cet état.
  int movableCount(List<int> state) {
    final cells = cellsOf(state);
    var count = 0;
    for (var i = 0; i < state.length; i++) {
      if (state[i] < 0) continue;
      if (slideWith(state, i, cells) != null) count++;
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

/// Ce qu'on apprend en rejouant une solution.
class SolutionWalk {
  const SolutionWalk({
    required this.choices,
    required this.optimalChoices,
    required this.wrongMoves,
    required this.deadEnds,
    required this.stopInteractions,
    required this.meaningfulStopInteractions,
    required this.dependencyMoves,
    required this.usedStopTiles,
    this.unresolvedAlternatives = 0,
  });

  /// Nombre de coups jouables à chaque étape de la solution.
  final List<int> choices;

  /// Parmi eux, ceux qui laissent la partie gagnable au plus court.
  ///
  /// C'est la vraie mesure de l'étroitesse : un board peut offrir cinq coups
  /// dont un seul passe.
  final List<int> optimalChoices;

  /// Coups écartés qui auraient allongé la partie.
  final int wrongMoves;

  /// Coups écartés qui l'auraient condamnée.
  final int deadEnds;

  /// Coups de la solution qui posent un bloc sur une tuile d'arrêt.
  final int stopInteractions;

  /// Parmi eux, ceux dont la nouvelle position change ce que les autres blocs
  /// peuvent faire. Les autres ne sont que des taps obligatoires.
  final int meaningfulStopInteractions;

  /// Coups de la solution qui modifient les possibilités d'un autre bloc.
  final int dependencyMoves;

  /// Tuiles effectivement utilisées par la solution.
  final int usedStopTiles;

  /// Alternatives dont le coût n'a pas pu être établi dans le budget.
  ///
  /// Ni bonnes, ni mauvaises, ni fatales : inconnues. Le nombre se publie pour
  /// qu'on sache à quel point une analyse s'appuie sur des trous — un candidat
  /// qui en accumule mérite d'être relu avec un budget plus large plutôt que
  /// classé sur des chiffres incomplets.
  final int unresolvedAlternatives;
}
