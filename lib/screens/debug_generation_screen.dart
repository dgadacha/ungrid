import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/engine/difficulty_config.dart';
import '../game/engine/difficulty_evaluator.dart';
import '../game/engine/game_engine.dart';
import '../game/engine/level_generator.dart';
import '../game/engine/level_solver.dart';
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
                    'NIVEAU $_levelId'
                    '${analysis.generated == null ? " · écrit" : " · généré"}',
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
                      ? 'REJOUER'
                      : 'COUP ${_step + 1}/${solution.length}',
                  onTap: _stepSolution,
                  accent: true,
                ),
                if (widget.progress != null)
                  _Chip(label: 'JOUER', onTap: _play),
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
    required this.generated,
    required this.config,
  });

  final Level level;
  final SolveResult solveResult;
  final DifficultyEvaluation difficulty;
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
    final config = analysis.config;
    final unmet =
        const DifficultyEvaluator().unmetCriteria(config, difficulty);

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
      children: [
        _row('Grille', '${level.columns} x ${level.rows}'),
        _row('Blocs', '${level.blocks.length}'),
        _row('Murs', '${level.walls.length}'),
        _row('Densité', '${(level.occupancy * 100).round()} %'),
        const Divider(height: 26),
        _row('Solvable', solve.solvable ? 'oui' : 'NON'),
        _row('Coups minimum', '${solve.minimumMoves}'),
        _row('Repositionnements',
            '${solve.minimumMoves - level.blocks.length}'),
        _row('Limite de coups',
            '${level.moveLimit}  (+${level.moveAllowance})'),
        _row('Sorties immédiates',
            '${LevelGenerator.exitableCount(level)}'
            ' (${(difficulty.exitableRatio * 100).round()} %)'),
        _row('Impasses croisées', '${solve.deadEndCount}'),
        _row('Coups forcés', '${solve.forcedMoveCount}'),
        _row('Points de choix', '${solve.decisionPointCount}'),
        _row('Choix moyen', solve.averageBranchingFactor.toStringAsFixed(2)),
        _row('États explorés',
            '${solve.exploredStates}${solve.exhaustive ? "" : "+"}'),
        const Divider(height: 26),
        _row('Score difficulté',
            '${difficulty.score.round()} · ${difficulty.tier.label}'),
        _row('Fenêtre visée',
            '${config.minScore.round()} - ${config.maxScore.round()}'),
        _row('Score visuel',
            '${analysis.generated?.quality.score.round() ?? "-"}'),
        _row('Essais', '${analysis.generated?.attempts ?? "-"}'),
        _row('Seed',
            '${seedForLevel(levelId, (analysis.generated?.attempts ?? 1) - 1)}'),
        _row('Génération', '${(generationMicros / 1000).toStringAsFixed(1)} ms'),
        if (unmet.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Critères non tenus : ${unmet.join(", ")}',
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
