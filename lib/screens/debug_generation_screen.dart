import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/engine/difficulty_config.dart';
import '../game/engine/difficulty_evaluator.dart';
import '../game/engine/game_engine.dart';
import '../game/engine/level_generator.dart';
import '../game/engine/level_solver.dart';
import '../game/engine/puzzle_analysis.dart';
import '../game/engine/solve_result.dart';
import '../game/engine/seeded_random.dart';
import '../game/levels/level_repository.dart';
import '../game/levels/manual_levels.dart';
import '../game/models/level.dart';
import '../game/painters/block_painter.dart';
import '../game/painters/debug_board_painter.dart';
import '../services/haptic_service.dart';
import '../services/progress_service.dart';
import '../widgets/ungrid_scaffold.dart';
import 'game_screen.dart';

/// Écran d'analyse de la génération.
///
/// Sans lui, régler les poids du générateur revient à tâtonner. On voit ici,
/// pour un niveau donné, la solution que le solveur a trouvée, ce qu'elle
/// coûte, et les notes obtenues — et on peut la rejouer coup par coup pour
/// vérifier que le puzzle tient debout.
class DebugGenerationScreen extends StatefulWidget {
  const DebugGenerationScreen({
    super.key,
    required this.repository,
    this.progress,
    this.haptics,
  });

  final LevelRepository repository;

  /// Fournis depuis les réglages : ils permettent d'essayer le niveau analysé
  /// sans repasser par la progression.
  final ProgressService? progress;
  final HapticService? haptics;

  @override
  State<DebugGenerationScreen> createState() => _DebugGenerationScreenState();
}

class _DebugGenerationScreenState extends State<DebugGenerationScreen> {
  static const LevelGenerator _generator = LevelGenerator();
  static const LevelSolver _solver = LevelSolver();
  static const PuzzleAnalyzer _analyzer = PuzzleAnalyzer();

  final BlockPainter _blockPainter = BlockPainter();

  int _levelId = 21;
  late _Analysis _analysis = _analyse(_levelId);

  /// Moteur de rejeu, pour dérouler la solution pas à pas.
  late GameEngine _playback = GameEngine(_analysis.level);
  int _step = 0;
  int _generationMicros = 0;

  _Analysis _analyse(int levelId) {
    final watch = Stopwatch()..start();
    late Level level;
    GeneratedLevel? generated;

    if (ManualLevels.contains(levelId)) {
      level = ManualLevels.byId(levelId);
    } else {
      generated = _generator.generate(levelId: levelId);
      level = generated.level;
    }
    watch.stop();
    _generationMicros = watch.elapsedMicroseconds;

    final solveResult = _solver.solve(level);
    final difficulty = const DifficultyEvaluator().evaluate(
      level,
      solveResult,
      LevelGenerator.exitableCount(level),
    );

    return _Analysis(
      level: level,
      solveResult: solveResult,
      difficulty: difficulty,
      puzzle: generated?.analysis ?? _analyzer.analyse(level, solveResult),
      band: bandFor(levelId),
      generated: generated,
      config: DifficultyCurve.configFor(levelId),
    );
  }

  void _load(int levelId) {
    if (levelId < 1) return;
    setState(() {
      _levelId = levelId;
      _analysis = _analyse(levelId);
      _playback = GameEngine(_analysis.level);
      _step = 0;
    });
  }

  /// Joue le coup suivant de la solution, ou repart de zéro.
  void _stepSolution() {
    final solution = _analysis.solveResult.exampleSolution;
    setState(() {
      if (_step >= solution.length) {
        _playback.reset();
        _step = 0;
        return;
      }
      _playback.tap(solution[_step]);
      _step++;
    });
  }

  void _play() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(
        levelId: _levelId,
        repository: widget.repository,
        progress: widget.progress!,
        haptics: widget.haptics!,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final analysis = _analysis;
    final solution = analysis.solveResult.exampleSolution;
    final blocks = analysis.level.blocks;

    final positions = [
      for (final block in blocks)
        _playback.blockById(block.id) == null
            ? -1
            : _playback.blockById(block.id)!.y * analysis.level.columns +
                _playback.blockById(block.id)!.x,
    ];
    final removed = <int>{
      for (var i = 0; i < blocks.length; i++)
        if (positions[i] < 0) i,
    };
    final next = _step < solution.length
        ? blocks.indexWhere((b) => b.id == solution[_step])
        : null;

    return UngridScaffold(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: UngridColors.onBackground),
                  splashRadius: 24,
                ),
                Expanded(
                  child: Text(
                    'LEVEL $_levelId'
                    '${analysis.generated == null ? " · handmade" : " · generated"}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => _load(_levelId),
                  icon: const Icon(Icons.refresh_rounded,
                      color: UngridColors.onBackground),
                  splashRadius: 24,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 300,
            child: CustomPaint(
              size: Size.infinite,
              painter: DebugBoardPainter(
                level: analysis.level,
                blocks: _blockPainter,
                positions: positions,
                removed: removed,
                nextInSolution: next != null && next >= 0 ? next : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(label: '-10', onTap: () => _load(_levelId - 10)),
                _Chip(label: '-1', onTap: () => _load(_levelId - 1)),
                _Chip(label: '+1', onTap: () => _load(_levelId + 1)),
                _Chip(label: '+10', onTap: () => _load(_levelId + 10)),
                _Chip(
                  label: _step >= solution.length
                      ? 'REPLAY'
                      : 'MOVE ${_step + 1}/${solution.length}',
                  onTap: _stepSolution,
                  accent: true,
                ),
                if (widget.progress != null)
                  _Chip(label: 'PLAY', onTap: _play),
              ],
            ),
          ),
          Expanded(
            child: _Stats(
              analysis: analysis,
              levelId: _levelId,
              generationMicros: _generationMicros,
            ),
          ),
        ],
      ),
    );
  }
}

class _Analysis {
  const _Analysis({
    required this.level,
    required this.solveResult,
    required this.difficulty,
    required this.puzzle,
    required this.band,
    required this.generated,
    required this.config,
  });

  final Level level;
  final SolveResult solveResult;
  final DifficultyEvaluation difficulty;
  final PuzzleAnalysis puzzle;
  final DifficultyBand band;
  final GeneratedLevel? generated;
  final DifficultyConfig config;
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: accent ? UngridColors.accent : UngridColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: UngridColors.onBackground,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({
    required this.analysis,
    required this.levelId,
    required this.generationMicros,
  });

  final _Analysis analysis;
  final int levelId;
  final int generationMicros;

  @override
  Widget build(BuildContext context) {
    final level = analysis.level;
    final solve = analysis.solveResult;
    final difficulty = analysis.difficulty;
    final puzzle = analysis.puzzle;
    final config = analysis.config;
    final unmet =
        const DifficultyEvaluator().unmetCriteria(config, difficulty);

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
      children: [
        _row('Band', analysis.band.name),
        _row('Grid', '${level.columns} x ${level.rows}'),
        _row('Blocks', '${level.blocks.length}'),
        _row('Walls', '${level.walls.length}'),
        _row('Density', '${(level.occupancy * 100).round()} %'),
        const Divider(height: 26),

        // Ce que le niveau demande vraiment : le nombre de coups seul ne dit
        // rien, deux niveaux de même longueur peuvent n'avoir rien à voir.
        _row('Optimal moves', '${solve.minimumMoves}'),
        _row('Moves / block',
            '${puzzle.moveComplexity.toStringAsFixed(2)}'
            '   target ${analysis.band.minComplexity.toStringAsFixed(2)}'
            '-${analysis.band.maxComplexity.toStringAsFixed(2)}'),
        _row('Replayed blocks',
            '${puzzle.multiMoveBlocks} (${(puzzle.multiMoveRatio * 100).round()} %)'
            '   target ${(analysis.band.minMultiMoveRatio * 100).round()} %'),
        _row('Choices per step', puzzle.averageChoices.toStringAsFixed(1)),
        _row('Steps with a choice',
            '${(puzzle.decisionRatio * 100).round()} %'),
        _row('Moves that cost', '${puzzle.wrongMoveOpportunities}'),
        _row('Moves that lose', '${puzzle.deadEndOpportunities}'),
        _row('Decision score',
            '${puzzle.decisionScore.round()}'
            '   target ${analysis.band.minDecisionScore.round()}'),
        const Divider(height: 26),

        _row('Move limit', '${level.moveLimit}'),
        _row('Instant exits',
            '${LevelGenerator.exitableCount(level)}'
            ' (${(difficulty.exitableRatio * 100).round()} %)'
            '   max ${(analysis.band.maxExitRatio * 100).round()} %'),
        _row('States explored',
            '${solve.exploredStates}${solve.exhaustive ? "" : "+"}'),
        _row('Difficulty score',
            '${difficulty.score.round()} · ${difficulty.tier.label}'),
        _row('Visual score',
            '${analysis.generated?.quality.score.round() ?? "-"}'),
        _row('Attempts', '${analysis.generated?.attempts ?? "-"}'),
        _row('Seed',
            '${seedForLevel(levelId, (analysis.generated?.attempts ?? 1) - 1)}'),
        _row('Generation', '${(generationMicros / 1000).toStringAsFixed(1)} ms'),
        if (unmet.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Unmet: ${unmet.join(", ")}',
              style: const TextStyle(
                color: UngridColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(height: 10),
        Text(
          config.toString(),
          style: const TextStyle(
            color: UngridColors.onBackgroundFaint,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                  color: UngridColors.onBackgroundSoft,
                  fontSize: 13,
                )),
            Text(value,
                style: const TextStyle(
                  color: UngridColors.onBackground,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                )),
          ],
        ),
      );
}
