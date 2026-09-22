import 'dart:async';

import 'package:flutter/material.dart';

import '../app/constants.dart';
import '../game/controllers/game_controller.dart';
import '../game/levels/level_repository.dart';
import '../game/levels/manual_levels.dart';
import '../services/haptic_service.dart';
import '../services/progress_service.dart';
import '../services/reward_service.dart';
import '../widgets/game_board.dart';
import '../widgets/game_header.dart';
import '../widgets/level_complete_overlay.dart';
import '../widgets/out_of_moves_overlay.dart';
import '../widgets/round_icon_button.dart';
import '../widgets/ungrid_scaffold.dart';

/// L'écran de jeu. La grille en occupe le centre, tout le reste s'efface.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.levelId,
    required this.repository,
    required this.progress,
    required this.haptics,
    this.rewards = const LocalRewardService(),
  });

  final int levelId;
  final LevelRepository repository;
  final ProgressService progress;
  final HapticService haptics;
  final RewardService rewards;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  GameController? _controller;
  late int _levelId = widget.levelId;

  bool _showOutcome = false;
  RecordsBeaten _records = const RecordsBeaten.none();
  LevelProgress? _best;
  Timer? _outcomeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load(_levelId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _outcomeTimer?.cancel();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  /// Le chronomètre mesure le temps réellement passé à jouer : il s'arrête dès
  /// que le jeu passe au second plan.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) return;
    if (state == AppLifecycleState.resumed) {
      controller.resumeTimer();
    } else {
      controller.pauseTimer();
    }
  }

  Future<void> _load(int levelId) async {
    final level = await widget.repository.levelFor(levelId);
    if (!mounted) return;

    setState(() {
      _levelId = levelId;
      _showOutcome = false;
      _records = const RecordsBeaten.none();
      _best = widget.progress.progressFor(levelId);
      if (_controller == null) {
        _controller = GameController(
          level: level,
          haptics: widget.haptics,
          rewards: widget.rewards,
        )..addListener(_onControllerChanged);
      } else {
        _controller!.loadLevel(level);
      }
    });

    widget.repository.prefetchAround(levelId);
  }

  void _onControllerChanged() {
    final controller = _controller;
    if (controller == null || controller.isPlaying || _showOutcome) return;
    if (_outcomeTimer?.isActive ?? false) return;

    // Laisser la sortie du dernier bloc, ou le refus, se jouer avant
    // d'annoncer l'issue.
    _outcomeTimer = Timer(
      controller.isCleared
          ? GameTiming.clearDelay + GameTiming.blockExit
          : GameTiming.blockedLabel,
      _presentOutcome,
    );
  }

  Future<void> _presentOutcome() async {
    final controller = _controller;
    if (controller == null || !mounted || controller.isPlaying) return;

    if (controller.isCleared) {
      final records = await widget.progress.recordCompletion(
        levelId: _levelId,
        movesUsed: controller.movesUsed,
        time: controller.elapsed,
      );
      if (!mounted) return;
      setState(() {
        _records = records;
        _showOutcome = true;
      });
    } else {
      setState(() => _showOutcome = true);
    }
  }

  void _next() {
    _outcomeTimer?.cancel();
    _load(_levelId + 1);
  }

  void _restart() {
    _outcomeTimer?.cancel();
    setState(() {
      _showOutcome = false;
      _controller?.restart();
    });
  }

  Future<void> _hint() async {
    final granted = await _controller?.requestHint() ?? false;
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun indice disponible pour le moment.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _extraMoves() async {
    final granted = await _controller?.requestExtraMoves() ?? false;
    if (granted && mounted) setState(() => _showOutcome = false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const UngridScaffold(
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return UngridScaffold(
      child: Stack(
        children: [
          Column(
            children: [
              GameHeader(
                controller: controller,
                levelId: _levelId,
                bestTime: _best?.bestTime,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(child: GameBoard(controller: controller)),
              _TutorialHint(levelId: _levelId),
              _Controls(
                controller: controller,
                onUndo: () => setState(controller.undo),
                onRestart: _restart,
                onHint: _hint,
              ),
              const SizedBox(height: 14),
            ],
          ),
          if (_showOutcome && controller.isCleared)
            Positioned.fill(
              child: LevelCompleteOverlay(
                movesUsed: controller.movesUsed,
                moveLimit: controller.moveLimit,
                elapsed: controller.elapsed,
                records: _records,
                isPerfect: controller.isPerfect,
                allowTapAnywhere: _levelId > 3,
                onNext: _next,
                onReplay: _restart,
              ),
            ),
          if (_showOutcome && controller.isOutOfMoves)
            Positioned.fill(
              child: OutOfMovesOverlay(
                remainingBlocks: controller.remainingBlocks,
                onRetry: _restart,
                onExtraMoves:
                    widget.rewards.isAvailable ? _extraMoves : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// La phrase d'apprentissage des premiers niveaux.
///
/// Elle occupe toujours la même hauteur, qu'il y ait un texte ou non : la
/// grille ne doit pas sauter d'un niveau à l'autre.
class _TutorialHint extends StatelessWidget {
  const _TutorialHint({required this.levelId});

  final int levelId;

  @override
  Widget build(BuildContext context) {
    final hint = ManualLevels.hintFor(levelId);
    return SizedBox(
      height: 34,
      child: hint == null
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
    );
  }
}

/// Les actions disponibles en cours de partie.
///
/// L'annulation reprend le dernier déplacement et rend le coup ; un refus,
/// lui, n'a rien déplacé et reste dû. C'est ce qui garde du poids à chaque tap
/// tout en pardonnant une fausse manoeuvre.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.onUndo,
    required this.onRestart,
    required this.onHint,
  });

  final GameController controller;
  final VoidCallback onUndo;
  final VoidCallback onRestart;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RoundIconButton(
            icon: Icons.undo_rounded,
            label: 'ANNULER',
            onPressed: controller.canUndo ? onUndo : null,
          ),
          const SizedBox(width: 30),
          RoundIconButton(
            icon: Icons.refresh_rounded,
            label: 'REJOUER',
            onPressed: controller.movesUsed > 0 ? onRestart : null,
          ),
          const SizedBox(width: 30),
          RoundIconButton(
            icon: Icons.lightbulb_outline_rounded,
            label: 'INDICE',
            onPressed: controller.isPlaying && controller.rewards.isAvailable
                ? onHint
                : null,
          ),
        ],
      ),
    );
  }
}
