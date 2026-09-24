import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../app/constants.dart';
import '../app/theme.dart';
import '../game/levels/level_repository.dart';
import '../services/haptic_service.dart';
import '../services/progress_service.dart';
import '../widgets/game_header.dart';
import '../widgets/ungrid_scaffold.dart';
import 'game_screen.dart';

/// Choix du niveau.
///
/// Chapitres de dix niveaux, progression et distinctions persistantes.
/// La campagne finie montre ses chapitres suivants verrouillés.
class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({
    super.key,
    required this.repository,
    required this.progress,
    required this.haptics,
  });

  final LevelRepository repository;
  final ProgressService progress;
  final HapticService haptics;

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  static const int _lockedPreview = 6;

  Future<void> _play(int levelId) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: GameTiming.screenTransition,
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: animation,
          child: GameScreen(
            levelId: levelId,
            repository: widget.repository,
            progress: widget.progress,
            haptics: widget.haptics,
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final unlocked = widget.progress.highestUnlockedLevel;
    final total = widget.repository.lastLevel ?? unlocked + _lockedPreview;

    return UngridScaffold(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 56, 4),
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
                    'LEVELS',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              itemCount: (total / 10).ceil(),
              itemBuilder: (context, chapterIndex) {
                final chapter = chapterIndex + 1;
                final cleared = widget.progress.chapterCleared(chapter);
                final mastered = widget.progress.chapterMastered(chapter);
                final start = chapterIndex * 10 + 1;
                final count = (total - start + 1).clamp(0, 10);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            cleared == 10
                                ? PhosphorIconsBold.medal
                                : PhosphorIconsBold.circle,
                            color: cleared == 10
                                ? UngridColors.success
                                : UngridColors.onBackgroundFaint,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'CHAPTER $chapter',
                              style: textTheme.titleMedium,
                            ),
                          ),
                          Text('$cleared/10', style: textTheme.labelLarge),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: cleared / 10,
                        color: UngridColors.success,
                        backgroundColor: UngridColors.surface,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$mastered mastered · ${cleared == 10 ? 'Medal collected' : '${10 - cleared} to chapter medal'}',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: .76,
                            ),
                        itemCount: count,
                        itemBuilder: (context, index) {
                          final levelId = start + index;
                          return _LevelTile(
                            levelId: levelId,
                            best: widget.progress.progressFor(levelId),
                            locked: levelId > unlocked,
                            isCurrent: levelId == unlocked,
                            onTap: levelId <= unlocked
                                ? () => _play(levelId)
                                : null,
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Une case de la liste des niveaux.
///
/// Elle montre ce qui donne envie d'y retourner : le meilleur temps réalisé.
class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.levelId,
    required this.best,
    required this.locked,
    required this.isCurrent,
    required this.onTap,
  });

  final int levelId;
  final LevelProgress? best;
  final bool locked;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final done = best?.completed ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: UngridColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent
                ? UngridColors.accent
                : done
                ? UngridColors.success.withValues(alpha: 0.5)
                : Colors.transparent,
            width: isCurrent ? 2.5 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (locked)
              const Icon(
                PhosphorIconsBold.lockKey,
                size: 20,
                color: UngridColors.onBackgroundFaint,
              )
            else ...[
              if (done)
                Icon(
                  best?.mastered == true
                      ? PhosphorIconsBold.medal
                      : PhosphorIconsBold.check,
                  size: 16,
                  color: best?.mastered == true
                      ? const Color(0xFFF8C471)
                      : UngridColors.success,
                ),
              Text(
                '$levelId',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: done
                      ? UngridColors.onBackground
                      : UngridColors.onBackgroundSoft,
                ),
              ),
              if (best?.bestTime != null) ...[
                const SizedBox(height: 3),
                Text(
                  formatPlayTime(best!.bestTime!),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: UngridColors.onBackgroundSoft,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
