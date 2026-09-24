import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../app/theme.dart';
import '../game/campaign/campaign_catalog.dart';
import '../game/campaign/playtest_plan.dart';
import '../game/engine/difficulty_config.dart';
import '../game/levels/level_repository.dart';
import '../game/models/level.dart';
import '../services/haptic_service.dart';
import '../services/progress_service.dart';
import '../widgets/ungrid_button.dart';
import '../widgets/ungrid_scaffold.dart';
import 'game_screen.dart';

/// Sauter à n'importe quel niveau, sans toucher à la progression.
///
/// Juger un palier demande de l'atteindre, et rejouer trente niveaux pour
/// voir à quoi ressemble le cinquantième n'apprend rien. On choisit donc le
/// numéro, on regarde ce qu'il contient, on l'essaie — et rien n'est
/// enregistré, sans quoi trois essais suffiraient à rendre la progression
/// réelle illisible.
class PlaytestScreen extends StatefulWidget {
  const PlaytestScreen({
    super.key,
    required this.repository,
    required this.progress,
    required this.haptics,
  });

  final LevelRepository repository;
  final ProgressService progress;
  final HapticService haptics;

  @override
  State<PlaytestScreen> createState() => _PlaytestScreenState();
}

class _PlaytestScreenState extends State<PlaytestScreen> {
  int _levelId = 1;
  Level? _preview;
  int _buildMicros = 0;
  LevelRepository? _challenge;
  bool _loadingChallenge = false;
  bool _fragile = false;
  bool _rotation = false;

  LevelRepository get _repository => _challenge ?? widget.repository;

  Future<void> _openChallenge() async {
    if (_loadingChallenge || (_challenge != null && !_fragile && !_rotation)) {
      return;
    }
    setState(() => _loadingChallenge = true);
    try {
      final catalog = await CampaignCatalog.load(path: PlaytestPlan.assetPath);
      if (!mounted) return;
      _challenge = LevelRepository(
        catalog: catalog,
        lastLevel: catalog.levelCount,
      );
      _fragile = false;
      _rotation = false;
      _load(1);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load the challenge. Try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingChallenge = false);
    }
  }

  Future<void> _openFragile({bool rotation = false}) async {
    if (_loadingChallenge || (rotation ? _rotation : _fragile)) return;
    setState(() => _loadingChallenge = true);
    try {
      final data =
          jsonDecode(
                await rootBundle.loadString(
                  rotation
                      ? 'assets/levels/rotation_v1.json'
                      : 'assets/levels/fragile_v1.json',
                ),
              )
              as Map<String, dynamic>;
      final levels = [
        for (final raw in data['levels'] as List)
          Level.fromJson(raw as Map<String, dynamic>),
      ];
      if (!mounted) return;
      _challenge = LevelRepository(
        fixedLevels: levels,
        lastLevel: levels.length,
      );
      _fragile = !rotation;
      _rotation = rotation;
      _load(1);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not load trials.')));
      }
    } finally {
      if (mounted) setState(() => _loadingChallenge = false);
    }
  }

  void _openOriginal() {
    _challenge = null;
    _rotation = false;
    _fragile = false;
    _load(1);
  }

  @override
  void initState() {
    super.initState();
    _load(_levelId);
  }

  /// Construit le niveau pour le montrer avant de le lancer.
  ///
  /// Le board se fabrique en quelques dizaines de millisecondes ; l'afficher
  /// évite de lancer une partie pour découvrir qu'on visait le mauvais palier.
  void _load(int levelId) {
    if (levelId < 1 ||
        (_repository.lastLevel != null && levelId > _repository.lastLevel!)) {
      return;
    }
    final watch = Stopwatch()..start();
    final level = _repository.levelForSync(levelId);
    watch.stop();
    setState(() {
      _levelId = levelId;
      _preview = level;
      _buildMicros = watch.elapsedMicroseconds;
    });
  }

  void _play() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          levelId: _levelId,
          repository: _repository,
          progress: widget.progress,
          haptics: widget.haptics,
          playtest: true,
        ),
      ),
    );
  }

  /// Le premier niveau de chaque tranche, et le milieu de la dernière ouverte.
  List<(String name, int levelId)> get _tiers {
    if (_rotation) return [('QUARTER TURN', 1), ('CHAIN REACTION', 6)];
    if (_fragile) return [('FIRST USE', 1), ('PLAN AHEAD', 6)];
    if (_challenge != null) {
      return [
        for (var i = 0; i < PlaytestPlan.chapters.length; i++)
          (PlaytestPlan.chapters[i], i * 5 + 1),
      ];
    }
    if (widget.repository.lastLevel != null) {
      return [
        for (final entry in [
          ('CHALLENGE', 1),
          ('ADVANCED', 21),
          ('EXPERT', 51),
          ('MASTERY', 81),
        ])
          if (entry.$2 <= widget.repository.lastLevel!) entry,
      ];
    }
    final tiers = <(String, int)>[];
    var from = 1;
    for (final band in difficultyBands) {
      tiers.add((band.name, from));
      // La dernière tranche n'a pas de fin : la campagne s'arrête à cent.
      from = band.upToLevel >= 1000 ? 100 : band.upToLevel + 1;
      if (from > 100) break;
    }
    return tiers;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final level = _preview;

    return UngridScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    PhosphorIconsBold.arrowLeft,
                    color: UngridColors.onBackground,
                  ),
                  splashRadius: 24,
                ),
                Expanded(
                  child: Text(
                    'PLAYTEST',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _loadingChallenge ? null : _openOriginal,
                      child: Text(
                        widget.repository.lastLevel == null
                            ? 'ORIGINAL'
                            : 'CAMPAIGN',
                      ),
                    ),
                    TextButton(
                      onPressed: _loadingChallenge ? null : _openChallenge,
                      child: Text(
                        _loadingChallenge ? 'LOADING…' : '20-LEVEL CHALLENGE',
                      ),
                    ),
                    TextButton(
                      onPressed: _loadingChallenge ? null : _openFragile,
                      child: const Text('FRAGILE · 10'),
                    ),
                    TextButton(
                      onPressed: _loadingChallenge
                          ? null
                          : () => _openFragile(rotation: true),
                      child: const Text('ROTATION · 10'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _challenge == null ? 'TIERS' : 'CHAPTERS',
                  style: textTheme.labelLarge,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (name, id) in _tiers)
                      _Chip(
                        label: '$name · $id',
                        selected: _levelId == id,
                        onTap: () => _load(id),
                      ),
                  ],
                ),
                const SizedBox(height: 26),

                Text('LEVEL', style: textTheme.labelLarge),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Chip(label: '-10', onTap: () => _load(_levelId - 10)),
                    _Chip(label: '-1', onTap: () => _load(_levelId - 1)),
                    Text(
                      '$_levelId',
                      style: textTheme.displaySmall ?? textTheme.headlineMedium,
                    ),
                    _Chip(label: '+1', onTap: () => _load(_levelId + 1)),
                    _Chip(label: '+10', onTap: () => _load(_levelId + 10)),
                  ],
                ),
                const SizedBox(height: 26),

                if (level != null) ...[
                  if (_challenge == null)
                    _Row(
                      'Band',
                      widget.repository.catalog
                              ?.definitionFor(_levelId)
                              ?.difficulty
                              .label ??
                          bandFor(_levelId).name,
                    )
                  else ...[
                    _Row(
                      'Chapter',
                      _rotation
                          ? 'QUARTER TURN'
                          : _fragile
                          ? 'ONE USE'
                          : PlaytestPlan.chapterFor(_levelId),
                    ),
                    _Row(
                      'Pace',
                      _rotation
                          ? 'Clockwise turns'
                          : _fragile
                          ? 'Fragile stops'
                          : _levelId <= 5
                          ? 'Introduction'
                          : PlaytestPlan.phaseFor(_levelId),
                    ),
                    _Row('Progress', '$_levelId / ${_repository.lastLevel}'),
                  ],
                  _Row('Grid', '${level.columns} x ${level.rows}'),
                  _Row('Blocks', '${level.blocks.length}'),
                  _Row(
                    'Stop tiles',
                    level.allStopTiles.isEmpty
                        ? 'none'
                        : '${level.allStopTiles.length}',
                  ),
                  // La réserve vaut l'optimal partout : un second chiffre
                  // identique n'apprendrait rien.
                  _Row('Moves', '${level.optimalMoves}'),
                  _Row(
                    'Moves / block',
                    (level.optimalMoves / level.blocks.length).toStringAsFixed(
                      2,
                    ),
                  ),
                  _Row(
                    'Built in',
                    '${(_buildMicros / 1000).toStringAsFixed(0)} ms',
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
            child: Column(
              children: [
                UngridButton(
                  label: 'PLAY LEVEL $_levelId',
                  onPressed: _play,
                  horizontalPadding: 32,
                ),
                const SizedBox(height: 10),
                Text(
                  'Nothing is saved: progress and records stay untouched.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? UngridColors.accent : UngridColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: UngridColors.onBackground,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: UngridColors.onBackgroundSoft,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: UngridColors.onBackground,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
