import 'package:flutter/foundation.dart';

import '../../app/constants.dart';
import '../../services/haptic_service.dart';
import '../../services/reward_service.dart';
import '../animations/block_animations.dart';
import '../engine/game_engine.dart';
import '../engine/level_solver.dart';
import '../models/level.dart';
import '../models/move_result.dart';

/// Issue d'une partie.
enum GameOutcome {
  /// La partie est en cours.
  playing,

  /// La grille est vide : niveau réussi.
  cleared,

  /// Plus de coups et des blocs encore là.
  outOfMoves,
}

/// Toute la partie en cours : le board, les coups restants, le chronomètre.
///
/// Le moteur ne connaît que les blocs. C'est ici que vivent la contrainte de
/// coups, le temps et l'indice — tout ce qui appartient à la partie plutôt
/// qu'au puzzle.
///
/// Deux mesures cohabitent, et il ne faut pas les confondre. Les coups
/// décident de la victoire : chaque bloc touché en consomme un, qu'il sorte ou
/// non, ce qui oblige à regarder la grille avant de jouer. Le temps ne décide
/// de rien ; il enregistre la performance, pour qu'on ait envie de refaire un
/// niveau déjà réussi.
class GameController extends ChangeNotifier {
  GameController({
    required Level level,
    required this.haptics,
    this.solver = const LevelSolver(),
    this.rewards = const LocalRewardService(),
    int? moveLimit,
  }) : _level = level,
       _moveLimit = moveLimit,
       engine = GameEngine(level) {
    _clock.start();
  }

  final HapticService haptics;
  final LevelSolver solver;
  final RewardService rewards;
  int _attempt = 0;
  bool usedHint = false;
  bool get mastered =>
      isCleared &&
      !usedHint &&
      bonusMoves == 0 &&
      movesUsed <= level.optimalMoves;

  Level _level;
  Level get level => _level;

  GameEngine engine;

  /// Horloge de référence des animations, en millisecondes depuis l'ouverture
  /// du niveau. Elle tourne en continu, indépendamment de la partie.
  final Stopwatch _clock = Stopwatch();

  /// Chronomètre de la partie : il démarre au premier coup, se suspend quand
  /// le jeu passe au second plan, et s'arrête sur l'issue.
  final Stopwatch _playTime = Stopwatch();

  /// Déplacements en cours de dessin. Le moteur a déjà appliqué le coup :
  /// ces animations ne font que le rendre visible.
  final List<BlockMotion> motions = [];

  /// Dernier déplacement joué, pour pouvoir le rejouer à l'envers.
  BlockMotion? _lastMotion;

  BlockedFeedback? blockedFeedback;
  PressFeedback? pressFeedback;

  /// Blocs dont le dessin est pris en charge par une animation.
  Set<String> get animatedBlockIds => {
    for (final motion in motions) motion.blockId,
  };

  /// Bloc désigné par l'indice, tant qu'il n'a pas été joué.
  String? hintedBlockId;

  int movesUsed = 0;

  /// Coups offerts en cours de partie, hors limite du niveau.
  int bonusMoves = 0;

  GameOutcome outcome = GameOutcome.playing;

  /// Horodatage du dernier changement du compteur, pour l'animer.
  int? _movesChangedAtMs;
  int? _outcomeAtMs;

  /// Les taps sont ignorés jusqu'à cette date.
  ///
  /// Le geste qui valide « suivant » ou « recommencer » ne doit pas retomber
  /// sur la grille qui vient d'apparaître : ce serait un coup dépensé sans
  /// que le joueur ait rien décidé.
  int _inputLockedUntilMs = 0;

  int get nowMs => _clock.elapsedMilliseconds;

  /// Coups accordés, fixés par la campagne. À défaut, ceux du niveau.
  int? _moveLimit;

  int get moveLimit => (_moveLimit ?? level.moveLimit) + bonusMoves;

  int get movesLeft {
    final left = moveLimit - movesUsed;
    return left < 0 ? 0 : left;
  }

  bool get isCleared => outcome == GameOutcome.cleared;
  bool get isOutOfMoves => outcome == GameOutcome.outOfMoves;
  bool get isPlaying => outcome == GameOutcome.playing;

  Duration get elapsed => _playTime.elapsed;

  bool get timerStarted => _playTime.elapsedMicroseconds > 0;

  int get remainingBlocks => engine.remainingCount;

  /// Progression de l'animation du compteur, de 1 vers 0.
  double get movesPulse {
    if (_movesChangedAtMs == null) return 0;
    final elapsed = nowMs - _movesChangedAtMs!;
    final total = GameTiming.counterPulse.inMilliseconds;
    if (elapsed >= total) return 0;
    return 1 - elapsed / total;
  }

  /// Tension des derniers coups, de 0 (confortable) à 1 (dernier coup).
  double get pressure {
    if (!isPlaying) return 0;
    if (movesLeft > 3) return 0;
    return (4 - movesLeft) / 4;
  }

  /// Impulsion du board à la fin de la partie, de 1 vers 0.
  double get clearPulse {
    if (_outcomeAtMs == null || !isCleared) return 0;
    final elapsed = nowMs - _outcomeAtMs!;
    final total = GameTiming.boardPulse.inMilliseconds;
    if (elapsed >= total) return 0;
    return 1 - elapsed / total;
  }

  /// Le jeu doit-il continuer à dessiner des frames ?
  bool get hasActiveAnimations =>
      motions.isNotEmpty ||
      blockedFeedback != null ||
      pressFeedback != null ||
      movesPulse > 0 ||
      clearPulse > 0;

  /// Joue la cellule touchée.
  ///
  /// Les taps hors grille, sur une case vide ou après la fin de la partie ne
  /// consomment rien : seul un bloc réellement touché coûte un coup.
  MoveResult tapCell(int x, int y) {
    if (!isPlaying) return const MoveResult.ignored();
    if (nowMs < _inputLockedUntilMs) return const MoveResult.ignored();

    final block = engine.blockAt(x, y);
    if (block == null) return const MoveResult.ignored();

    pressFeedback = PressFeedback(blockId: block.id, startMs: nowMs);
    if (!_playTime.isRunning && !timerStarted) _playTime.start();

    final result = engine.tap(block.id);
    movesUsed++;
    _movesChangedAtMs = nowMs;
    if (hintedBlockId == block.id) hintedBlockId = null;

    switch (result.outcome) {
      case MoveOutcome.exited:
        _push(
          BlockMotion.exit(
            block: block,
            columns: level.columns,
            rows: level.rows,
            startMs: nowMs,
          ),
        );
      case MoveOutcome.slid:
      case MoveOutcome.stopped:
        final moved = engine.blockById(block.id)!;
        _push(
          BlockMotion.slide(
            block: moved,
            fromX: block.x,
            fromY: block.y,
            startMs: nowMs,
          ),
        );
        if (result.stopped) haptics.stoppedOnTile();
      case MoveOutcome.blocked:
        blockedFeedback = BlockedFeedback(block: block, startMs: nowMs);
        haptics.blocked();
      case MoveOutcome.ignored:
        break;
    }

    _updateOutcome();
    notifyListeners();
    return result;
  }

  void _push(BlockMotion motion) {
    motions.add(motion);
    _lastMotion = motion;
  }

  /// La victoire est évaluée avant la défaite : vider la grille avec son
  /// dernier coup est une réussite, pas un échec.
  void _updateOutcome() {
    if (engine.isCompleted) {
      _finish(GameOutcome.cleared);
      haptics.levelClear();
    } else if (movesLeft <= 0) {
      _finish(GameOutcome.outOfMoves);
      haptics.gameOver();
    } else if (motions.isNotEmpty) {
      haptics.blockExit();
    }
  }

  void _finish(GameOutcome result) {
    outcome = result;
    _outcomeAtMs = nowMs;
    _playTime.stop();
  }

  /// Suspend le chronomètre : passage en arrière-plan, publicité, dialogue
  /// système. Le temps passé hors du jeu ne doit pas compter.
  void pauseTimer() {
    if (_playTime.isRunning) _playTime.stop();
  }

  void resumeTimer() {
    if (isPlaying && timerStarted && !_playTime.isRunning) _playTime.start();
  }

  /// Retire les animations terminées. Appelé à chaque frame par la vue.
  void pruneAnimations() {
    final now = nowMs;
    motions.removeWhere((motion) => motion.isDone(now));
    if (blockedFeedback?.isDone(now) ?? false) blockedFeedback = null;
    if (pressFeedback?.isDone(now) ?? false) pressFeedback = null;
  }

  /// Un coup peut-il être repris ?
  ///
  /// Seuls les coups qui ont modifié le plateau s'annulent : un refus n'a rien
  /// déplacé, et le rembourser reviendrait à autoriser le joueur à tout tester
  /// sans rien risquer.
  bool get canUndo => !isCleared && engine.canUndo;

  /// Reprend le dernier déplacement, en le rejouant à l'envers.
  ///
  /// Le coup est rendu au joueur ; le chronomètre, lui, continue de courir —
  /// le temps passé à revenir sur ses pas a bien été passé.
  void undo() {
    if (!canUndo) return;

    final record = engine.undo();
    if (record == null) return;

    movesUsed = movesUsed > 0 ? movesUsed - 1 : 0;
    if (isOutOfMoves && movesLeft > 0) {
      outcome = GameOutcome.playing;
      _outcomeAtMs = null;
      resumeTimer();
    }
    blockedFeedback = null;
    _movesChangedAtMs = nowMs;
    hintedBlockId = null;

    final motion = _lastMotion;
    motions.clear();
    if (motion != null && motion.blockId == record.blockId) {
      motions.add(
        BlockMotion.reverse(
          motion,
          nowMs,
          restoredDirection: record.directionBefore,
        ),
      );
    }
    _lastMotion = null;

    notifyListeners();
  }

  /// Désigne un bloc jouable, sans le jouer : le joueur garde la main.
  ///
  /// Le chronomètre est suspendu le temps de la récompense.
  Future<bool> requestHint() async {
    if (!isPlaying || !rewards.isAvailable) return false;

    final attempt = _attempt;
    pauseTimer();
    final granted = await rewards.requestReward(RewardType.hint);
    if (attempt != _attempt || !isPlaying) return false;
    resumeTimer();
    if (!granted) return false;

    hintedBlockId = solver.nextBestMove(level, engine.history);
    if (hintedBlockId != null) usedHint = true;
    notifyListeners();
    return hintedBlockId != null;
  }

  /// Rend la main au joueur après une défaite, avec quelques coups de plus.
  ///
  /// La grille n'est pas réinitialisée : la partie reprend exactement où elle
  /// s'était arrêtée.
  Future<bool> requestExtraMoves({int amount = 3}) async {
    if (!isOutOfMoves || !rewards.isAvailable) return false;

    final attempt = _attempt;
    pauseTimer();
    final granted = await rewards.requestReward(RewardType.extraMoves);
    if (attempt != _attempt || !isOutOfMoves || !granted) return false;

    bonusMoves += amount;
    outcome = GameOutcome.playing;
    _outcomeAtMs = null;
    _movesChangedAtMs = nowMs;
    resumeTimer();
    notifyListeners();
    return true;
  }

  /// Fait la sourde oreille le temps qu'un geste de transition se termine.
  void lockInput([Duration duration = GameTiming.inputLock]) {
    _inputLockedUntilMs = nowMs + duration.inMilliseconds;
  }

  /// Recharge le niveau. Immédiat, sans confirmation.
  void restart() {
    _attempt++;
    usedHint = false;
    engine.reset();
    motions.clear();
    _lastMotion = null;
    blockedFeedback = null;
    pressFeedback = null;
    hintedBlockId = null;
    movesUsed = 0;
    bonusMoves = 0;
    outcome = GameOutcome.playing;
    _movesChangedAtMs = null;
    _outcomeAtMs = null;
    _playTime
      ..stop()
      ..reset();
    lockInput();
    notifyListeners();
  }

  @override
  void dispose() {
    _attempt++;
    super.dispose();
  }

  /// Passe à un autre niveau sans recréer le contrôleur : l'enchaînement d'un
  /// niveau au suivant doit être instantané.
  void loadLevel(Level next, {int? moveLimit}) {
    _level = next;
    _moveLimit = moveLimit;
    engine = GameEngine(next);
    restart();
  }
}
