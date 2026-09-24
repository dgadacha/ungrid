import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../app/constants.dart';
import '../app/strings.dart';
import '../app/theme.dart';
import '../game/controllers/game_controller.dart';
import '../game/levels/level_repository.dart';
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
    this.playtest = false,
  });

  final int levelId;
  final LevelRepository repository;
  final ProgressService progress;
  final HapticService haptics;
  final RewardService rewards;

  /// Partie d'essai : rien n'est enregistré.
  ///
  /// On vient ici pour juger un palier, pas pour progresser. Enregistrer la
  /// victoire débloquerait la suite et écraserait les records d'un joueur qui
  /// ne jouait pas vraiment — après trois niveaux essayés au hasard, sa
  /// progression ne voudrait plus rien dire.
  final bool playtest;

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
  String? _rewardLabel;

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
      _rewardLabel = null;
      // En essai, aucun record à battre : la partie ne compte pas.
      _best = widget.playtest ? null : widget.progress.progressFor(levelId);
      if (_controller == null) {
        _controller = GameController(
          level: level,
          haptics: widget.haptics,
          rewards: widget.rewards,
          paletteIndex: widget.progress.paletteIndex,
          moveLimit: widget.repository.moveLimitFor(levelId, level),
        )..addListener(_onControllerChanged);
      } else {
        _controller!.loadLevel(
          level,
          moveLimit: widget.repository.moveLimitFor(levelId, level),
        );
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
      final completedId = _levelId;
      final palettesBefore = widget.progress.unlockedPalettes.length;
      final records = widget.playtest
          ? const RecordsBeaten.none()
          : await widget.progress.recordCompletion(
              levelId: _levelId,
              movesUsed: controller.movesUsed,
              time: controller.elapsed,
              mastered: controller.mastered,
            );
      if (!mounted || _levelId != completedId || !controller.isCleared) return;
      setState(() {
        final palettes = widget.progress.unlockedPalettes;
        _rewardLabel = !widget.playtest && palettes.length > palettesBefore
            ? '${UngridColors.paletteNames[palettes.last]} UNLOCKED · See Rewards'
            : null;
        _records = records;
        _showOutcome = true;
      });
    } else {
      setState(() => _showOutcome = true);
    }
  }

  void _next() {
    _outcomeTimer?.cancel();
    if (widget.repository.lastLevel != null &&
        _levelId >= widget.repository.lastLevel!) {
      Navigator.of(context).pop();
      return;
    }
    _load(_levelId + 1);
  }

  void _undo() {
    if (!(_controller?.canUndo ?? false)) return;
    _outcomeTimer?.cancel();
    setState(() {
      _showOutcome = false;
      _controller!.undo();
    });
  }

  void _restart() {
    _outcomeTimer?.cancel();
    setState(() {
      _showOutcome = false;
      _rewardLabel = null;
      _controller?.restart();
    });
  }

  Future<void> _hint() async {
    final granted = await _controller?.requestHint() ?? false;
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Strings.of(context).noHint),
          duration: const Duration(seconds: 2),
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
              // La grille est servie à son format exact plutôt qu'étirée sur
              // tout l'espace : sans cela elle se centre dans une zone plus
              // haute qu'elle, et la phrase en dessous se retrouve collée aux
              // boutons au lieu de respirer entre les deux.
              Flexible(
                flex: 5,
                child: AspectRatio(
                  aspectRatio:
                      controller.level.columns / controller.level.rows,
                  child: GameBoard(controller: controller),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Builder(
                      builder: (context) {
                        if (controller.level.rotationTiles.isNotEmpty) {
                          return Text(
                            Strings.of(context).rotationRule,
                            textAlign: TextAlign.center,
                          );
                        }
                        if (controller.level.fragileStopTiles.isNotEmpty) {
                          return Text(
                            Strings.of(context).fragileRule,
                            textAlign: TextAlign.center,
                          );
                        }
                        if (widget.playtest) return const _PlaytestBanner();
                        return _TutorialHint(levelId: _levelId);
                      },
                    ),
                  ),
                ),
              ),
              _Controls(
                controller: controller,
                onUndo: _undo,
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
                elapsed: controller.elapsed,
                records: _records,
                mastered: controller.mastered,
                rewardLabel: _rewardLabel,
                chapter: widget.playtest ? null : (_levelId - 1) ~/ 10 + 1,
                chapterCleared: widget.playtest
                    ? 0
                    : widget.progress.chapterCleared((_levelId - 1) ~/ 10 + 1),
                allowTapAnywhere: _levelId > 3,
                onNext: _next,
                onReplay: _restart,
                nextLabel: _levelId == widget.repository.lastLevel
                    ? 'FINISH'
                    : 'NEXT',
              ),
            ),
          if (_showOutcome && controller.isOutOfMoves)
            Positioned.fill(
              child: OutOfMovesOverlay(
                remainingBlocks: controller.remainingBlocks,
                onRetry: _restart,
                onUndo: controller.canUndo ? _undo : null,
                onExtraMoves: widget.rewards.isAvailable ? _extraMoves : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// La phrase d'apprentissage des premiers niveaux.
///
/// Elle réserve toujours la même hauteur, qu'il y ait un texte ou non, pour
/// que la grille ne saute pas d'un niveau à l'autre — et cette hauteur tient
/// deux lignes, sinon la phrase vient mordre sur les boutons.
/// Rappelle que la partie ne compte pas.
///
/// Sans lui, on finit par oublier qu'on est en essai et par s'étonner que la
/// progression n'ait pas bougé.
class _PlaytestBanner extends StatelessWidget {
  const _PlaytestBanner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Center(
        child: Text(
          Strings.of(context).playtestBanner,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: UngridColors.onBackgroundFaint,
          ),
        ),
      ),
    );
  }
}

class _TutorialHint extends StatelessWidget {
  const _TutorialHint({required this.levelId});

  final int levelId;

  @override
  Widget build(BuildContext context) {
    final hint = Strings.of(context).tutorial(levelId);
    return SizedBox(
      height: 54,
      child: hint == null
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(28, 4, 28, 10),
              child: Text(
                hint,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
            icon: PhosphorIconsBold.arrowCounterClockwise,
            label: Strings.of(context).undo,
            onPressed: controller.canUndo ? onUndo : null,
          ),
          const SizedBox(width: 30),
          RoundIconButton(
            icon: PhosphorIconsBold.arrowClockwise,
            label: Strings.of(context).restart,
            onPressed: controller.movesUsed > 0 ? onRestart : null,
          ),
          const SizedBox(width: 30),
          RoundIconButton(
            icon: PhosphorIconsBold.lightbulb,
            label: Strings.of(context).hint,
            onPressed: controller.isPlaying && controller.rewards.isAvailable
                ? onHint
                : null,
          ),
        ],
      ),
    );
  }
}
