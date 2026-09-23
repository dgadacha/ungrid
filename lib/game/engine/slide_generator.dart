import 'dart:math' as math;

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

  /// Construit un puzzle à partir de la seule seed.
  ///
  /// C'est la forme qui compte pour la campagne : le catalogue ne retient
  /// qu'un nombre, et le board se reconstruit à l'identique chez tout le
  /// monde. Aucun paramètre extérieur n'entre ici — taille de grille, nombre
  /// de blocs, rondes et murs se tirent tous du même générateur pseudo-
  /// aléatoire.
  Level? fromSeed(int seed, {int levelId = 0, int? stopTileBudget});
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

  /// Construit le seul noeud de dépendance, sans rien autour.
  ///
  /// Sert à vérifier le motif isolément : il doit demander un coup de plus
  /// qu'il n'a de blocs.
  static Level? debugKnotOnly({
    required int seed,
    required DifficultyConfig config,
  }) {
    final board = _Rewind(
      config.gridSize,
      config.gridSize,
      stopBudget: config.stopTileBudget,
      stopThreshold: _stopThreshold(config.targetBlocks),
    );
    if (!board.seedKnot(SeededRandom(seed))) return null;
    return Level(
      id: 0,
      rows: config.gridSize,
      columns: config.gridSize,
      blocks: board.toBlocks(),
      stopTiles: board.toStopTiles(),
      optimalMoves: board.moveCount,
    );
  }

  /// Nombre de candidats de tête conservés pour le tirage.
  static const int _shortlistSize = 5;

  /// Poids du tirage : le meilleur candidat est favorisé sans être
  /// systématique, sinon tous les niveaux se ressemblent.
  static const List<double> _weights = [0.38, 0.24, 0.17, 0.12, 0.09];

  @override
  Level? fromSeed(int seed, {int levelId = 0, int? stopTileBudget}) {
    final shape = SeededRandom(seed ^ 0x5bf03635);

    // La forme du board fait partie du tirage : c'est ce qui donne à la
    // campagne des niveaux variés à partir d'une simple liste de seeds.
    final gridSize = switch (shape.nextInt(100)) {
      < 12 => 4,
      < 45 => 5,
      < 80 => 6,
      _ => 7,
    };
    final cells = gridSize * gridSize;
    final density = 0.18 + shape.nextDouble() * 0.20;
    final target = (cells * density).round().clamp(4, (cells * 0.45).floor());

    final config = DifficultyConfig(
      scalar: shape.nextDouble(),
      gridSize: gridSize,
      minBlocks: target,
      maxBlocks: target,
      repositionRatio: 0.2 + shape.nextDouble() * 1.4,
      maxExitableRatio: 1,
      minScore: 0,
      maxScore: 1000,
      knotCount: target >= 9 ? shape.nextInt(target >= 14 ? 3 : 2) : 0,
      // Bornes provisoires : deux tuiles sur un 4x4, une de plus par cran de
      // grille. UNGRID doit rester lisible — c'est le benchmark qui dira si
      // elles peuvent bouger.
      stopTileBudget: stopTileBudget ?? shape.nextInt(gridSize - 1),
    );

    return buildCandidate(levelId: levelId, seed: seed, config: config);
  }

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
      stopTiles: board.toStopTiles(),
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
    final board = _Rewind(
      size,
      size,
      stopBudget: config.stopTileBudget,
      stopThreshold: _stopThreshold(targetBlocks),
    );
    if (strict) board.seedKnots(config.knotCount, random);

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

  /// Blocs à poser avant qu'une tuile ait une chance de servir.
  ///
  /// Proportionnel au board visé plutôt qu'absolu : un seuil fixe priverait
  /// les petites grilles de la mécanique, or c'est là qu'on l'enseigne.
  ///
  /// Le board doit être presque complet. Posée plus tôt, la tuile retient un
  /// bloc sur une case que personne ne croise encore, et le rembobinage ne
  /// sait pas si quelqu'un la croisera plus tard.
  static int _stopThreshold(int targetBlocks) =>
      math.max(4, (targetBlocks * 0.9).round());

  /// Plus il manque de blocs, plus on en fait entrer ; une fois le compte
  /// atteint, on ne fait plus que repositionner.
  ///
  /// La part laissée aux reculs compte plus qu'il n'y paraît. Une entrée fige
  /// tout le trajet de sortie du bloc qu'elle pose, et une tuile ne peut pas
  /// se poser sur un trajet figé : si toutes les entrées passent d'abord, il
  /// ne reste plus une case libre pour une tuile quand les reculs arrivent.
  /// On les entrelace donc.
  double _entryChance(_Rewind board, int targetBlocks) {
    final missing = targetBlocks - board.blockCount;
    if (missing <= 0) return 0;
    return (0.20 + missing / targetBlocks * 0.35).clamp(0.0, 0.62);
  }
}

/// Board en cours de rembobinage.
class _Rewind {
  _Rewind(
    this.columns,
    this.rows, {
    this.stopBudget = 0,
    this.stopThreshold = 0,
  })
      : _cells = List<int>.filled(columns * rows, -1),
        _stops = List<bool>.filled(columns * rows, false);

  final int columns;
  final int rows;

  /// Index du bloc occupant chaque case, -1 si vide.
  final List<int> _cells;

  /// Tuiles d'arrêt posées jusqu'ici.
  final List<bool> _stops;

  /// Tuiles que la construction s'autorise encore à poser.
  final int stopBudget;

  /// Blocs qu'il faut avoir posés avant qu'une tuile puisse servir.
  ///
  /// Une tuile pose un bloc sur une case ; tant que le board est presque vide,
  /// cette case ne coupe la route de personne et l'arrêt n'est qu'un tap de
  /// plus. Mesuré : en n'autorisant les tuiles que sur un board déjà garni, la
  /// part d'arrêts porteurs d'une dépendance passe de 34 % à 65 %, et le score
  /// de difficulté de 37 à 51.
  final int stopThreshold;

  int _stopsUsed = 0;

  int get stopsUsed => _stopsUsed;

  final List<int> _x = [];
  final List<int> _y = [];
  final List<Direction> _directions = [];

  int _moves = 0;

  /// Blocs posés par les rondes : ce sont eux qu'il est payant de reculer.
  int knottedBlocks = 0;

  int get blockCount => _x.length;

  /// Nombre de coups que la solution demandera.
  int get moveCount => _moves;

  bool _isFree(int x, int y) => _cells[y * columns + x] < 0;

  bool _hasStop(int x, int y) => _stops[y * columns + x];


  /// Une tuile peut-elle retenir un bloc sur cette case ?
  /// Une tuile peut-elle retenir un bloc sur cette case ?
  ///
  /// On ne vérifie pas qu'elle épargne les coups déjà construits, et c'est
  /// délibéré. Une tuile posée sur le trajet d'un coup planifié ne casse pas
  /// la solution : elle l'allonge, le bloc s'arrêtant là où il passait. Le
  /// rembobinage cesse donc d'être une preuve pour redevenir ce qu'il est —
  /// une bonne façon de proposer des positions ; c'est le solveur qui tranche.
  ///
  /// Le prix est mesuré : dix points de candidats solvables en moins. Le gain
  /// l'est aussi, et il est ailleurs. Une tuile qui gêne un autre bloc est
  /// forcément posée sur le chemin de ce bloc : l'interdire revenait à
  /// n'autoriser que les tuiles qui ne servent à rien. Elles sont passées de
  /// 18 % à 34 % d'arrêts porteurs d'une dépendance, et le rapport coups /
  /// blocs de 1,16 à 1,32 de moyenne.
  bool _canPlaceStop(int x, int y, int block) =>
      _stopsUsed < stopBudget &&
      !_stops[y * columns + x] &&
      blockCount >= stopThreshold &&
      // La case doit couper la route de quelqu'un. Sans cela, le bloc s'y
      // pose, rien ne change pour personne, et le joueur a simplement tapé
      // une fois de plus : la solution s'allonge sans qu'il y ait à décider.
      _blocksInterrupted(x, y, ignore: block) > 0;

  void _placeStop(int x, int y) {
    _stops[y * columns + x] = true;
    _stopsUsed++;
  }

  /// Ce qui retient le bloc [i] là où il est.
  ///
  /// Sans justification, le recul est interdit : un bloc que rien n'arrête ne
  /// se serait jamais posé là.
  _Stopper _stopperOf(int i) {
    final direction = _directions[i];
    final aheadX = _x[i] + direction.dx;
    final aheadY = _y[i] + direction.dy;
    if (_inside(aheadX, aheadY) && !_isFree(aheadX, aheadY)) {
      return _Stopper.block;
    }
    if (_hasStop(_x[i], _y[i])) return _Stopper.stopTile;
    if (_canPlaceStop(_x[i], _y[i], i)) return _Stopper.newStopTile;
    return _Stopper.none;
  }

  /// Ce que vaut une tuile posée sous le bloc [i].
  ///
  /// Le bloc viendra s'arrêter là ; sa présence sur cette case doit changer ce
  /// qu'un autre peut faire, sinon l'arrêt n'est qu'un tap de plus. On compte
  /// donc les blocs dont la route passe par cette case — ceux qu'il bloquera
  /// une fois posé, et qu'il faudra donc jouer avant lui, ou débloquer après.
  double _stopValue(int i) {
    final blocked = _blocksInterrupted(_x[i], _y[i], ignore: i);
    if (blocked == 0) return -5.0;
    return 3.0 + blocked * 7.0;
  }

  /// Reculs possibles pour le bloc [i], du plus proche au plus lointain.
  ///
  /// On s'arrête à la première tuile rencontrée : elle peut servir de case de
  /// départ — un bloc qui démarre sur une tuile n'est pas retenu — mais rien
  /// au-delà, car le bloc s'y poserait avant d'arriver.
  List<(int x, int y, int distance)> _pullBackRoom(int i) {
    final direction = _directions[i];
    final room = <(int, int, int)>[];
    var x = _x[i];
    var y = _y[i];
    var distance = 0;

    while (true) {
      x -= direction.dx;
      y -= direction.dy;
      if (!_inside(x, y) || !_isFree(x, y)) break;
      distance++;
      room.add((x, y, distance));
      if (_hasStop(x, y)) break;
    }
    return room;
  }

  /// Applique un recul : le bloc remonte à la case d'où il aurait glissé.
  void _applyPullBack(int index, int x, int y, _Stopper stopper) {
    if (stopper == _Stopper.newStopTile) _placeStop(_x[index], _y[index]);
    _cells[_y[index] * columns + _x[index]] = -1;
    _x[index] = x;
    _y[index] = y;
    _cells[y * columns + x] = index;
    _moves++;
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
    _place(chosen.x, chosen.y, chosen.direction);
    _moves++;
    return true;
  }

  /// Défait un glissement : un bloc recule jusqu'à la case d'où il serait
  /// venu.
  ///
  /// Le recul n'est valable que si quelque chose arrête le bloc là où il se
  /// trouve. Deux choses le peuvent, et c'est toute la différence :
  ///
  /// - **un bloc devant lui**, ce qui exige que la position soit déjà nouée —
  ///   le solveur retirera souvent l'obstacle d'abord, et le détour ne sera
  ///   obligatoire que pris dans un blocage circulaire ;
  /// - **une tuile d'arrêt**, qui retient sans rien devoir à personne. Le
  ///   détour devient alors inconditionnel : aucun ordre de jeu ne l'évite.
  ///
  /// C'est ce second cas qui lève le plafond du rapport coups / blocs : un
  /// coup de plus s'obtient sans les quatre blocs qu'une ronde réclamait.
  bool rewindPullBack(
    SeededRandom random,
    int shortlist,
    List<double> weights, {
    bool strict = false,
  }) {
    final candidates = <_Candidate>[];
    final stoppers = <int, _Stopper>{};

    for (var i = 0; i < blockCount; i++) {
      final stopper = _stopperOf(i);
      if (stopper == _Stopper.none) continue;
      stoppers[i] = stopper;

      // Un recul justifié par un bloc, le solveur l'évite : il retire
      // l'obstacle d'abord et le détour ne sert à rien. Justifié par une
      // tuile, il ne s'évite pas.
      //
      // Encore faut-il que le détour serve à quelque chose. Une tuile pose le
      // bloc sur une case ; si cette case ne coupe la route de personne, le
      // joueur tape une fois de plus et rien d'autre ne change — la solution
      // s'allonge sans qu'il y ait à décider. Mesuré : ces tuiles-là font
      // chuter l'étroitesse du chemin optimal de 84 % et le score de
      // difficulté de 22 %. On regarde donc ce que la case retient avant de la
      // choisir, et un arrêt qui n'engage personne passe en dernier.
      final tileBonus = stopper == _Stopper.newStopTile
          ? _stopValue(i)
          : 0.0;

      for (final (x, y, distance) in _pullBackRoom(i)) {
        candidates.add(_Candidate(
          x: x,
          y: y,
          direction: _directions[i],
          stopper: stopper,
          block: i,
          score: _pullBackScore(i, x, y, distance) + tileBonus,
        ));
      }
    }
    if (candidates.isEmpty) return false;

    final chained = _chainOnly(candidates, strict: strict);
    if (chained.isEmpty) return false;

    final chosen = _pick(chained, random, shortlist, weights);
    final index = chosen.block!;
    _applyPullBack(index, chosen.x, chosen.y, stoppers[index]!);
    return true;
  }

  /// Pose un noeud de quatre blocs qui oblige à jouer deux fois le même.
  ///
  /// Le rembobinage seul produit surtout des niveaux où chaque bloc sort d'un
  /// tap : le solveur retire l'obstacle avant de jouer le bloc, et le
  /// déplacement intermédiaire devient inutile. Pour qu'il soit obligatoire,
  /// il faut un enchaînement fermé, et le plus simple est une ronde :
  ///
  ///     A → . . B
  ///     .       ↓
  ///     ↑       .
  ///     D . . ← C
  ///
  /// Chacun bute sur le suivant, personne ne peut sortir. Le seul coup ouvert
  /// est de pousser l'un d'eux, ce qui libère son voisin, et de proche en
  /// proche la ronde se défait — le bloc poussé ne sortant qu'à la fin, joué
  /// deux fois.
  ///
  /// Retourne `false` si la grille ne s'y prête pas ; la génération continue
  /// alors normalement.
  /// Pose autant de rondes que possible, jusqu'à [count].
  ///
  /// Chacune ajoute un coup à la solution sans ajouter de sortie : c'est le
  /// levier principal pour faire monter le rapport coups / blocs.
  int seedKnots(int count, SeededRandom random) {
    var placed = 0;
    for (var i = 0; i < count; i++) {
      if (!seedKnot(random)) break;
      placed++;
    }
    knottedBlocks = blockCount;
    return placed;
  }

  bool seedKnot(SeededRandom random) {
    // Un côté d'au moins deux cases : il faut de la place pour glisser.
    final rectangles = <(int, int, int, int)>[
      for (var y1 = 0; y1 < rows - 2; y1++)
        for (var y2 = y1 + 2; y2 < rows; y2++)
          for (var x1 = 0; x1 < columns - 2; x1++)
            for (var x2 = x1 + 2; x2 < columns; x2++) (x1, y1, x2, y2),
    ];
    if (rectangles.isEmpty) return false;
    random.shuffle(rectangles);

    for (final (x1, y1, x2, y2) in rectangles) {
      for (final clockwise in [true, false]) {
        // Les quatre coins et le sens de leur flèche.
        final corners = clockwise
            ? [
                (x1, y1, Direction.right),
                (x2, y1, Direction.down),
                (x2, y2, Direction.left),
                (x1, y2, Direction.up),
              ]
            : [
                (x1, y1, Direction.down),
                (x1, y2, Direction.right),
                (x2, y2, Direction.up),
                (x2, y1, Direction.left),
              ];

        if (!_knotFits(corners)) continue;
        if (!_knotSparesOthers(corners)) continue;

        var added = 0;
        for (final (x, y, direction) in corners) {
          // Un coin déjà tenu par le bon bloc est réutilisé : deux rondes qui
          // partagent des blocs coûtent moins cher en place, et font monter
          // d'autant le rapport coups / blocs.
          if (!_isFree(x, y)) continue;
          _place(x, y, direction);
          added++;
        }
        if (added == 0) continue;

        // Une sortie à défaire par bloc posé, plus le coup qui dénoue la ronde.
        _moves += added + 1;
        return true;
      }
    }
    return false;
  }

  /// La nouvelle ronde laisse-t-elle les blocs déjà posés s'en aller ?
  ///
  /// Une ronde qui se referme sur la route d'une autre condamnerait les deux :
  /// on vérifie donc qu'aucun de ses coins ne tombe sur un trajet de sortie
  /// déjà nécessaire.
  bool _knotSparesOthers(List<(int, int, Direction)> corners) {
    for (var i = 0; i < blockCount; i++) {
      final direction = _directions[i];
      var cx = _x[i] + direction.dx;
      var cy = _y[i] + direction.dy;
      while (_inside(cx, cy)) {
        for (final (x, y, _) in corners) {
          // Une case déjà occupée par ce bloc-là n'est pas une gêne nouvelle.
          if (cx == x && cy == y && _isFree(x, y)) return false;
        }
        cx += direction.dx;
        cy += direction.dy;
      }
    }
    return true;
  }

  /// La ronde tient-elle sur cette grille ?
  ///
  /// Il faut les quatre coins libres, les côtés dégagés — sans quoi les blocs
  /// ne butent pas les uns sur les autres — et une sortie praticable pour
  /// chacun une fois la ronde défaite.
  bool _knotFits(List<(int, int, Direction)> corners) {
    for (final (x, y, direction) in corners) {
      if (_isFree(x, y)) continue;
      // Un bloc déjà là ne convient que s'il regarde dans le bon sens : la
      // ronde ne se referme qu'à cette condition.
      final index = _cells[y * columns + x];
      if (index < 0 || _directions[index] != direction) return false;
    }

    for (var i = 0; i < corners.length; i++) {
      final (x, y, direction) = corners[i];
      final (nextX, nextY, _) = corners[(i + 1) % corners.length];

      // Le côté qui mène au voisin doit être vide : un mur au milieu
      // arrêterait le bloc trop tôt et le condamnerait.
      var cx = x + direction.dx;
      var cy = y + direction.dy;
      var reached = false;
      while (_inside(cx, cy)) {
        if (cx == nextX && cy == nextY) {
          reached = true;
          break;
        }
        if (!_isFree(cx, cy)) return false;
        cx += direction.dx;
        cy += direction.dy;
      }
      if (!reached) return false;

      // Au-delà du voisin, la route vers le bord doit rester praticable ;
      // un bloc partagé par une autre ronde y est admis, il partira avant.
      

      cx = nextX + direction.dx;
      cy = nextY + direction.dy;
      while (_inside(cx, cy)) {
        if (!_isFree(cx, cy)) return false;
        cx += direction.dx;
        cy += direction.dy;
      }
    }
    return true;
  }

  bool _inside(int x, int y) =>
      x >= 0 && y >= 0 && x < columns && y < rows;

  void _place(int x, int y, Direction direction) {
    _cells[y * columns + x] = blockCount;
    _x.add(x);
    _y.add(y);
    _directions.add(direction);
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

    final stoppers = <int, _Stopper>{};

    for (var i = 0; i < blockCount; i++) {
      final stopper = _stopperOf(i);
      if (stopper == _Stopper.none) continue;
      stoppers[i] = stopper;

      final direction = _directions[i];
      final originX = _x[i];
      final originY = _y[i];

      final placesTile = stopper == _Stopper.newStopTile;

      for (final (x, y, _) in _pullBackRoom(i)) {
        // Essai à blanc : on recule, on compte, on remet. La tuile fait
        // partie du geste, donc de l'essai.
        _cells[originY * columns + originX] = -1;
        _cells[y * columns + x] = i;
        _x[i] = x;
        _y[i] = y;
        if (placesTile) _stops[originY * columns + originX] = true;
        final after = exitableCount();
        if (placesTile) _stops[originY * columns + originX] = false;
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
            stopper: stopper,
            score: -after.toDouble(),
          );
        }
      }
    }

    if (best == null) return false;
    final index = best.block!;
    _applyPullBack(index, best.x, best.y, stoppers[index]!);
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
    _place(best.x, best.y, best.direction);
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
        // Une tuile posée referme une sortie, mais pas celle d'un voisin :
        // celle du bloc qu'elle retient. Sans ce cas, le geste qui donne
        // toute sa valeur à la mécanique était systématiquement écarté.
        if (candidate.stopper == _Stopper.newStopTile ||
            _exitableInterrupted(candidate.x, candidate.y,
                    ignore: candidate.block) >
                0)
          candidate,
    ];
    if (closing.isNotEmpty) return closing;
    return strict ? const [] : candidates;
  }

  /// `true` si rien n'arrête le bloc entre cette case et le bord.
  ///
  /// Une tuile sur le trajet suffit à l'empêcher de sortir : elle compte donc
  /// autant qu'un bloc. Celle posée sous la case de départ, en revanche, ne
  /// retient pas le bloc qui la quitte.
  bool _pathIsClear(int x, int y, Direction direction) {
    var cx = x + direction.dx;
    var cy = y + direction.dy;
    while (cx >= 0 && cy >= 0 && cx < columns && cy < rows) {
      if (!_isFree(cx, cy)) return false;
      if (_stops[cy * columns + cx]) return false;
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

    // De la place derrière, sinon le bloc ne pourra jamais reculer : il
    // sortira d'un seul tap quoi qu'il arrive. C'est ce qui manquait pour que
    // les tuiles servent — un bloc collé au bord d'entrée n'a nulle part où
    // être repoussé.
    score += (_backRoom(x, y, direction)).clamp(0, 2) * 1.6;

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
  ///
  /// Reculer un bloc déjà noué compte double : il devra être joué une fois de
  /// plus, et c'est exactement ce qui fait monter le rapport coups / blocs
  /// au-delà de ce qu'une ronde seule permet.
  double _pullBackScore(int index, int x, int y, int distance) {
    var score = 1.0 + distance * 1.4;
    score += _exitableInterrupted(x, y, ignore: index) * 14.0;
    score += _blocksInterrupted(x, y, ignore: index) * 3.0;
    if (index < knottedBlocks) score += 8.0;
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
        // Une tuile rencontrée plus tôt retient le bloc : il n'ira pas plus
        // loin, et la case visée ne lui coupe donc rien.
        if (_hasStop(cx, cy)) break;
      }
    }
    return count;
  }

  /// Cases libres derrière le bloc, dans le sens opposé à sa flèche.
  int _backRoom(int x, int y, Direction direction) {
    var cx = x - direction.dx;
    var cy = y - direction.dy;
    var count = 0;
    while (_inside(cx, cy) && _isFree(cx, cy)) {
      count++;
      cx -= direction.dx;
      cy -= direction.dy;
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

  /// Les tuiles posées, dans l'ordre des cases.
  List<GridPosition> toStopTiles() => [
        for (var cell = 0; cell < _stops.length; cell++)
          if (_stops[cell]) GridPosition(cell % columns, cell ~/ columns),
      ];

  List<Block> toBlocks() => [
        for (var i = 0; i < blockCount; i++)
          Block(
            id: 'b$i',
            position: GridPosition(_x[i], _y[i]),
            direction: _directions[i],
          ),
      ];
}

/// Ce qui retient un bloc là où il est, et ce que le recul coûtera.
enum _Stopper {
  /// Rien ne l'arrête : il n'a pas pu s'y poser.
  none,

  /// Un bloc lui barre la route.
  block,

  /// Une tuile déjà posée le retient.
  stopTile,

  /// Une tuile reste à poser sous lui, et le budget le permet.
  newStopTile,
}

class _Candidate {
  const _Candidate({
    required this.x,
    required this.y,
    required this.direction,
    required this.score,
    this.block,
    this.stopper = _Stopper.none,
  });

  final int x;
  final int y;
  final Direction direction;
  final double score;

  /// Index du bloc reculé, `null` pour une entrée.
  final int? block;

  /// Ce qui retiendra le bloc une fois reculé.
  final _Stopper stopper;
}

/// Réexport pratique pour les appelants qui composent difficulté et tier.
Difficulty tierOf(DifficultyConfig config) => config.tier;
