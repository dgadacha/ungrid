import '../models/block.dart';
import '../models/difficulty.dart';
import '../models/direction.dart';
import '../models/grid_position.dart';
import '../models/level.dart';
import 'difficulty_config.dart';
import 'seeded_random.dart';

/// Contrat commun aux générateurs de niveaux.
abstract class PuzzleGenerator {
  Level? buildCandidate({
    required int levelId,
    required int seed,
    required DifficultyConfig config,
  });
}

/// Génération par rembobinage.
///
/// Le principe : ne jamais tirer un board au hasard en espérant qu'il soit
/// jouable. On part de la grille vide — c'est-à-dire de la victoire — et on
/// remonte le temps, coup par coup, en défaisant des mouvements. Deux gestes
/// suffisent : faire rentrer un bloc par le bord, ou reculer un bloc déjà posé
/// jusqu'à la case d'où il aurait glissé.
///
/// Chaque état traversé est donc, par construction, une position gagnable : il
/// suffit de rejouer la séquence à l'endroit. Le niveau livré au joueur est le
/// dernier état obtenu, et sa solution est connue avant même qu'il y touche.
///
/// C'est la seule méthode raisonnable ici. Depuis que les blocs glissent, un
/// board tiré au hasard mène presque toujours à une impasse, et la vérifier
/// coûte une exploration complète.
class SlideGenerator implements PuzzleGenerator {
  const SlideGenerator();

  /// Nombre de candidats de tête conservés pour le tirage.
  static const int _shortlistSize = 5;

  /// Poids du tirage : le meilleur candidat est favorisé sans être
  /// systématique, sinon tous les niveaux se ressemblent.
  static const List<double> _weights = [0.38, 0.24, 0.17, 0.12, 0.09];

  @override
  Level? buildCandidate({
    required int levelId,
    required int seed,
    required DifficultyConfig config,
  }) {
    final size = config.gridSize;
    final targetBlocks = config.minBlocks +
        SeededRandom(seed).nextInt(config.maxBlocks - config.minBlocks + 1);

    // Coups de repositionnement en plus des entrées : c'est ce qui transforme
    // un board « tout le monde sort » en vrai puzzle.
    final targetMoves =
        targetBlocks + (targetBlocks * config.repositionRatio).round();

    // Première passe, nouée : on n'accepte que les gestes qui referment la
    // sortie encore ouverte, de façon à n'en laisser qu'une à tout instant.
    // Elle seule mène à un board sans coup gratuit, où le joueur doit
    // commencer par pousser un bloc.
    var board = _build(
      size: size,
      config: config,
      seed: seed,
      targetBlocks: targetBlocks,
      targetMoves: targetMoves,
      strict: true,
    );

    // Si la contrainte a étouffé la construction, on la relâche : mieux vaut
    // un niveau moins noué qu'un niveau vide.
    if (board.blockCount < config.minBlocks) {
      board = _build(
        size: size,
        config: config,
        seed: seed,
        targetBlocks: targetBlocks,
        targetMoves: targetMoves,
        strict: false,
      );
    }

    if (board.blockCount < 2) return null;

    return Level(
      id: levelId,
      rows: size,
      columns: size,
      blocks: board.toBlocks(),
      walls: board.wallPositions(),
      // Le rembobinage donne une solution ; le solveur dira si elle est la
      // plus courte.
      optimalMoves: board.moveCount,
      difficulty: config.tier,
      seed: seed,
    );
  }

  _Rewind _build({
    required int size,
    required DifficultyConfig config,
    required int seed,
    required int targetBlocks,
    required int targetMoves,
    required bool strict,
  }) {
    final random = SeededRandom(seed);
    final board = _Rewind(size, size);
    board.placeWalls(config.maxWalls, random);

    var guard = targetMoves * 6;
    while (board.moveCount < targetMoves && guard-- > 0) {
      final needsBlock = board.blockCount < targetBlocks;
      final wantsEntry = needsBlock &&
          (board.blockCount == 0 ||
              board.moveCount == 0 ||
              random.nextDouble() < _entryChance(board, targetBlocks));

      final played = wantsEntry
          ? board.rewindEntry(random, _shortlistSize, _weights, strict: strict)
          : board.rewindPullBack(random, _shortlistSize, _weights,
                  strict: strict) ||
              board.rewindEntry(random, _shortlistSize, _weights,
                  strict: strict);

      if (!played) break;
    }

    // Dernier geste : refermer ce qui reste ouvert. Tant qu'un bloc peut
    // quitter la grille d'un seul coup, le joueur a un coup gratuit.
    if (board.blockCount >= 2) board.closeExits(targetBlocks * 2);
    return board;
  }

  /// Plus il manque de blocs, plus on en fait entrer ; une fois le compte
  /// atteint, on ne fait plus que repositionner.
  double _entryChance(_Rewind board, int targetBlocks) {
    final missing = targetBlocks - board.blockCount;
    if (missing <= 0) return 0;
    return (0.35 + missing / targetBlocks * 0.5).clamp(0.0, 0.9);
  }
}

/// Board en cours de rembobinage.
class _Rewind {
  _Rewind(this.columns, this.rows)
      : _cells = List<int>.filled(columns * rows, -1),
        _walls = List<bool>.filled(columns * rows, false);

  final int columns;
  final int rows;

  /// Index du bloc occupant chaque case, -1 si vide.
  final List<int> _cells;
  final List<bool> _walls;

  final List<int> _x = [];
  final List<int> _y = [];
  final List<Direction> _directions = [];

  int _moves = 0;

  int get blockCount => _x.length;

  /// Nombre de coups que la solution demandera.
  int get moveCount => _moves;

  bool _isFree(int x, int y) =>
      _cells[y * columns + x] < 0 && !_walls[y * columns + x];

  /// Pose les murs, avant tout bloc.
  ///
  /// Ils se tiennent à l'écart des bords et les uns des autres : collés au
  /// bord ils condamneraient des lignes entières, collés entre eux ils
  /// formeraient un pâté qui ferme le board au lieu de l'organiser.
  void placeWalls(int count, SeededRandom random) {
    if (count <= 0) return;
    final margin = columns >= 6 ? 1 : 0;
    final cells = <(int, int)>[
      for (var y = margin; y < rows - margin; y++)
        for (var x = margin; x < columns - margin; x++) (x, y),
    ];
    random.shuffle(cells);

    var placed = 0;
    for (final (x, y) in cells) {
      if (placed >= count) break;
      if (_tooCloseToWall(x, y)) continue;
      _walls[y * columns + x] = true;
      placed++;
    }
  }

  bool _tooCloseToWall(int x, int y) {
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final cx = x + dx;
        final cy = y + dy;
        if (cx < 0 || cy < 0 || cx >= columns || cy >= rows) continue;
        if (_walls[cy * columns + cx]) return true;
      }
    }
    return false;
  }

  /// Défait une sortie : un bloc rentre par le bord.
  ///
  /// La case choisie doit avoir la route libre jusqu'à la sortie, sans quoi le
  /// coup correspondant ne ferait pas sortir le bloc.
  bool rewindEntry(
    SeededRandom random,
    int shortlist,
    List<double> weights, {
    bool strict = false,
  }) {
    final candidates = <_Candidate>[];
    final lastResort = <_Candidate>[];

    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        if (!_isFree(x, y)) continue;
        for (final direction in Direction.values) {
          if (!_pathIsClear(x, y, direction)) continue;
          final candidate = _Candidate(
            x: x,
            y: y,
            direction: direction,
            score: _entryScore(x, y, direction),
          );
          // Un bloc collé au bord, flèche vers l'extérieur, ne pourra jamais
          // être retenu par quoi que ce soit : il restera un coup gratuit
          // jusqu'à la fin de la partie. On ne s'en sert qu'en dernier
          // recours, quand la grille n'offre plus rien d'autre.
          if (_distanceToExit(x, y, direction) == 0) {
            lastResort.add(candidate);
          } else {
            candidates.add(candidate);
          }
        }
      }
    }
    if (candidates.isEmpty) candidates.addAll(lastResort);
    if (candidates.isEmpty) return false;

    final chained = _chainOnly(candidates, strict: strict);
    if (chained.isEmpty) return false;

    final chosen = _pick(chained, random, shortlist, weights);
    _cells[chosen.y * columns + chosen.x] = blockCount;
    _x.add(chosen.x);
    _y.add(chosen.y);
    _directions.add(chosen.direction);
    _moves++;
    return true;
  }

  /// Défait un glissement : un bloc recule jusqu'à la case d'où il serait
  /// venu.
  ///
  /// Le recul n'est valable que si quelque chose arrête le bloc là où il se
  /// trouve : sans obstacle devant lui, il ne s'y serait jamais arrêté.
  bool rewindPullBack(
    SeededRandom random,
    int shortlist,
    List<double> weights, {
    bool strict = false,
  }) {
    final candidates = <_Candidate>[];

    for (var i = 0; i < blockCount; i++) {
      final direction = _directions[i];
      final aheadX = _x[i] + direction.dx;
      final aheadY = _y[i] + direction.dy;
      final stopped = aheadX >= 0 &&
          aheadY >= 0 &&
          aheadX < columns &&
          aheadY < rows &&
          !_isFree(aheadX, aheadY);
      if (!stopped) continue;

      var x = _x[i];
      var y = _y[i];
      var distance = 0;
      while (true) {
        x -= direction.dx;
        y -= direction.dy;
        if (x < 0 || y < 0 || x >= columns || y >= rows) break;
        if (!_isFree(x, y)) break;
        distance++;
        candidates.add(_Candidate(
          x: x,
          y: y,
          direction: direction,
          block: i,
          score: _pullBackScore(i, x, y, distance),
        ));
      }
    }
    if (candidates.isEmpty) return false;

    final chained = _chainOnly(candidates, strict: strict);
    if (chained.isEmpty) return false;

    final chosen = _pick(chained, random, shortlist, weights);
    final index = chosen.block!;
    _cells[_y[index] * columns + _x[index]] = -1;
    _x[index] = chosen.x;
    _y[index] = chosen.y;
    _cells[chosen.y * columns + chosen.x] = index;
    _moves++;
    return true;
  }

  /// Blocs qui quitteraient la grille dès le premier coup.
  int exitableCount() {
    var count = 0;
    for (var i = 0; i < blockCount; i++) {
      if (_pathIsClear(_x[i], _y[i], _directions[i])) count++;
    }
    return count;
  }

  /// Referme la dernière sortie ouverte.
  ///
  /// Sans cette passe, il reste toujours un bloc qui quitte la grille d'un
  /// seul coup : le joueur a un coup gratuit et n'a rien à repositionner. On
  /// cherche donc à couper sa route.
  ///
  /// Un recul est préférable — il ne rajoute rien au board et referme
  /// vraiment. Quand aucun n'y parvient, on prolonge la chaîne d'un bloc : la
  /// sortie change de propriétaire, la géométrie change avec elle, et un recul
  /// devient souvent possible au tour suivant.
  void closeExits(int maxSteps, {int maxExtraBlocks = 4}) {
    var guard = maxSteps;
    var extra = maxExtraBlocks;

    while (guard-- > 0) {
      if (exitableCount() == 0) break;
      if (_closeWithPullBack()) continue;
      if (extra > 0 && _closeWithEntry()) {
        extra--;
        continue;
      }
      break;
    }
  }

  /// Recule un bloc en travers d'une sortie encore ouverte.
  bool _closeWithPullBack() {
    final open = exitableCount();
    var bestOpen = open;
    _Candidate? best;

    for (var i = 0; i < blockCount; i++) {
      final direction = _directions[i];
      final aheadX = _x[i] + direction.dx;
      final aheadY = _y[i] + direction.dy;
      final stopped = aheadX >= 0 &&
          aheadY >= 0 &&
          aheadX < columns &&
          aheadY < rows &&
          !_isFree(aheadX, aheadY);
      if (!stopped) continue;

      final originX = _x[i];
      final originY = _y[i];
      var x = originX;
      var y = originY;

      while (true) {
        x -= direction.dx;
        y -= direction.dy;
        if (x < 0 || y < 0 || x >= columns || y >= rows) break;
        if (!_isFree(x, y)) break;

        // Essai à blanc : on recule, on compte, on remet.
        _cells[originY * columns + originX] = -1;
        _cells[y * columns + x] = i;
        _x[i] = x;
        _y[i] = y;
        final after = exitableCount();
        _cells[y * columns + x] = -1;
        _x[i] = originX;
        _y[i] = originY;
        _cells[originY * columns + originX] = i;

        if (after < bestOpen) {
          bestOpen = after;
          best = _Candidate(
            x: x,
            y: y,
            direction: direction,
            block: i,
            score: -after.toDouble(),
          );
        }
      }
    }

    if (best == null) return false;
    final index = best.block!;
    _cells[_y[index] * columns + _x[index]] = -1;
    _x[index] = best.x;
    _y[index] = best.y;
    _cells[best.y * columns + best.x] = index;
    _moves++;
    return true;
  }

  /// Pose un bloc en travers d'une sortie encore ouverte.
  ///
  /// Le compte de sorties ne baisse pas — le nouveau venu prend la place du
  /// précédent — mais la chaîne s'allonge, et avec elle les chances qu'un
  /// recul puisse la refermer ensuite. On évite les cases trop proches du
  /// bord, d'où un bloc ne pourrait plus jamais être retenu.
  bool _closeWithEntry() {
    _Candidate? best;
    var bestScore = double.negativeInfinity;

    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        if (!_isFree(x, y)) continue;
        if (_exitableInterrupted(x, y) == 0) continue;
        for (final direction in Direction.values) {
          if (_distanceToExit(x, y, direction) <= 1) continue;
          if (!_pathIsClear(x, y, direction)) continue;

          final score = _entryScore(x, y, direction);
          if (score > bestScore) {
            bestScore = score;
            best = _Candidate(
              x: x,
              y: y,
              direction: direction,
              score: score,
            );
          }
        }
      }
    }

    if (best == null) return false;
    _cells[best.y * columns + best.x] = blockCount;
    _x.add(best.x);
    _y.add(best.y);
    _directions.add(best.direction);
    _moves++;
    return true;
  }

  /// En mode strict, aucun geste ne passe s'il ne referme rien : la
  /// construction s'arrête plutôt que de laisser une deuxième sortie
  /// s'ouvrir, car on ne saurait plus la refermer ensuite. Sinon, on se
  /// contente de préférer les gestes qui referment.
  List<_Candidate> _chainOnly(
    List<_Candidate> candidates, {
    required bool strict,
  }) {
    if (exitableCount() == 0) return candidates;
    final closing = [
      for (final candidate in candidates)
        if (_exitableInterrupted(candidate.x, candidate.y,
                ignore: candidate.block) >
            0)
          candidate,
    ];
    if (closing.isNotEmpty) return closing;
    return strict ? const [] : candidates;
  }

  bool _pathIsClear(int x, int y, Direction direction) {
    var cx = x + direction.dx;
    var cy = y + direction.dy;
    while (cx >= 0 && cy >= 0 && cx < columns && cy < rows) {
      if (!_isFree(cx, cy)) return false;
      cx += direction.dx;
      cy += direction.dy;
    }
    return true;
  }

  /// Un bloc qui rentre doit barrer la route de ceux déjà posés.
  ///
  /// C'est tout l'enjeu : un bloc posé sans rien gêner pourra sortir dès le
  /// premier coup, et n'aura rien apporté au puzzle. On cherche au contraire à
  /// refermer les sorties ouvertes par les gestes précédents, pour que le
  /// joueur ait à les rouvrir dans le bon ordre.
  double _entryScore(int x, int y, Direction direction) {
    var score = 1.0;
    // Refermer une sortie encore ouverte prime sur tout le reste : c'est ce
    // qui enchaîne les blocs les uns aux autres au lieu de les juxtaposer.
    score += _exitableInterrupted(x, y) * 14.0;
    score += _blocksInterrupted(x, y) * 3.0;
    score += _spaceBonus(x, y);
    score -= _crowding(x, y) * 1.4;
    score -= _repetitionPenalty(x, y, direction);

    final room = _distanceToExit(x, y, direction);
    if (room == 0) {
      score -= 9;
    } else if (room == 1) {
      // À une case du bord, seule une pose exactement sur cette case pourrait
      // encore le retenir : c'est trop peu de prise.
      score -= 7;
    } else {
      score += room * 0.5;
    }
    return score;
  }

  /// Un recul est utile s'il éloigne le bloc de sa sortie et, mieux encore,
  /// s'il vient se mettre en travers d'un autre.
  double _pullBackScore(int index, int x, int y, int distance) {
    var score = 1.0 + distance * 1.4;
    score += _exitableInterrupted(x, y, ignore: index) * 14.0;
    score += _blocksInterrupted(x, y, ignore: index) * 3.0;
    score += _spaceBonus(x, y);
    score -= _crowding(x, y) * 1.2;
    score -= _repetitionPenalty(x, y, _directions[index]);
    return score;
  }

  /// Blocs encore capables de quitter la grille dont la route passe par
  /// (x, y).
  ///
  /// C'est la mesure qui compte pour nouer le puzzle. Gêner un bloc déjà
  /// bloqué ne change rien au nombre de coups gratuits offerts au joueur ;
  /// couper la route d'un bloc qui pouvait sortir, si.
  int _exitableInterrupted(int x, int y, {int? ignore}) {
    var count = 0;
    for (var i = 0; i < blockCount; i++) {
      if (i == ignore) continue;
      // Un bloc sortable a toute sa route libre : il suffit de vérifier que
      // la case est devant lui, sur son axe.
      if (!_pathIsClear(_x[i], _y[i], _directions[i])) continue;
      final direction = _directions[i];
      var cx = _x[i] + direction.dx;
      var cy = _y[i] + direction.dy;
      while (cx >= 0 && cy >= 0 && cx < columns && cy < rows) {
        if (cx == x && cy == y) {
          count++;
          break;
        }
        cx += direction.dx;
        cy += direction.dy;
      }
    }
    return count;
  }

  /// Blocs dont la course s'arrêterait si on occupait la case (x, y).
  ///
  /// On ne compte que ceux qui passent réellement par là dans l'état courant :
  /// un bloc déjà arrêté plus tôt ne serait pas gêné davantage.
  int _blocksInterrupted(int x, int y, {int? ignore}) {
    var count = 0;
    for (var i = 0; i < blockCount; i++) {
      if (i == ignore) continue;
      final direction = _directions[i];
      var cx = _x[i];
      var cy = _y[i];
      while (true) {
        cx += direction.dx;
        cy += direction.dy;
        if (cx < 0 || cy < 0 || cx >= columns || cy >= rows) break;
        if (cx == x && cy == y) {
          count++;
          break;
        }
        if (!_isFree(cx, cy)) break;
      }
    }
    return count;
  }

  double _distanceToExit(int x, int y, Direction direction) =>
      switch (direction) {
        Direction.up => y.toDouble(),
        Direction.down => (rows - 1 - y).toDouble(),
        Direction.left => x.toDouble(),
        Direction.right => (columns - 1 - x).toDouble(),
      };

  /// Bonus pour les quadrants peu remplis : le board doit rester équilibré.
  double _spaceBonus(int x, int y) {
    if (blockCount == 0) return 0;
    final halfX = columns / 2;
    final halfY = rows / 2;
    final counts = List<int>.filled(4, 0);
    for (var i = 0; i < blockCount; i++) {
      counts[(_x[i] < halfX ? 0 : 1) + (_y[i] < halfY ? 0 : 2)]++;
    }
    final quadrant = (x < halfX ? 0 : 1) + (y < halfY ? 0 : 2);
    final minCount = counts.reduce((a, b) => a < b ? a : b);
    return counts[quadrant] == minCount ? 2 : 0;
  }

  int _crowding(int x, int y) {
    var total = 0;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        final cx = x + dx;
        final cy = y + dy;
        if (cx < 0 || cy < 0 || cx >= columns || cy >= rows) continue;
        if (_cells[cy * columns + cx] >= 0) total++;
      }
    }
    return total;
  }

  /// Pénalise les suites de flèches identiques, qui donnent un board
  /// mécanique : `> > > >` ne se lit pas comme un puzzle.
  double _repetitionPenalty(int x, int y, Direction direction) {
    var penalty = 0.0;
    var sameAdjacent = 0;
    for (final step in Direction.values) {
      final cx = x + step.dx;
      final cy = y + step.dy;
      if (cx < 0 || cy < 0 || cx >= columns || cy >= rows) continue;
      final index = _cells[cy * columns + cx];
      if (index >= 0 && _directions[index] == direction) sameAdjacent++;
    }
    if (sameAdjacent >= 2) penalty += 5;
    if (sameAdjacent == 1) penalty += 1.5;
    return penalty;
  }

  _Candidate _pick(
    List<_Candidate> candidates,
    SeededRandom random,
    int shortlistSize,
    List<double> weights,
  ) {
    candidates.sort((a, b) => b.score.compareTo(a.score));
    final shortlist = candidates.take(shortlistSize).toList();

    var total = 0.0;
    for (var i = 0; i < shortlist.length; i++) {
      total += weights[i < weights.length ? i : weights.length - 1];
    }
    var roll = random.nextDouble() * total;
    for (var i = 0; i < shortlist.length; i++) {
      roll -= weights[i < weights.length ? i : weights.length - 1];
      if (roll <= 0) return shortlist[i];
    }
    return shortlist.last;
  }

  List<Block> toBlocks() => [
        for (var i = 0; i < blockCount; i++)
          Block(
            id: 'b$i',
            position: GridPosition(_x[i], _y[i]),
            direction: _directions[i],
          ),
      ];

  List<GridPosition> wallPositions() => [
        for (var y = 0; y < rows; y++)
          for (var x = 0; x < columns; x++)
            if (_walls[y * columns + x]) GridPosition(x, y),
      ];
}

class _Candidate {
  const _Candidate({
    required this.x,
    required this.y,
    required this.direction,
    required this.score,
    this.block,
  });

  final int x;
  final int y;
  final Direction direction;
  final double score;

  /// Index du bloc reculé, `null` pour une entrée.
  final int? block;
}

/// Réexport pratique pour les appelants qui composent difficulté et tier.
Difficulty tierOf(DifficultyConfig config) => config.tier;
