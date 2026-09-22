import 'package:flutter/material.dart';

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
/// Les niveaux ne sont pas stockés mais reconstruits à la demande : la liste
/// n'a donc pas de fin. On montre ce qui est ouvert, plus quelques cases
/// verrouillées pour donner à voir la suite.
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
    final total = unlocked + _lockedPreview;

    return UngridScaffold(
      child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 56, 4),
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
                      'LEVELS',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 30),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.88,
                ),
                itemCount: total,
                itemBuilder: (context, index) {
                  final levelId = index + 1;
                  return _LevelTile(
                    levelId: levelId,
                    best: widget.progress.progressFor(levelId),
                    locked: levelId > unlocked,
                    isCurrent: levelId == unlocked,
                    onTap: levelId <= unlocked ? () => _play(levelId) : null,
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
              const Icon(Icons.lock_rounded,
                  size: 20, color: UngridColors.onBackgroundFaint)
            else ...[
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
