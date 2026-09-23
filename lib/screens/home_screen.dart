import 'package:flutter/material.dart';

import '../app/constants.dart';
import '../app/theme.dart';
import '../widgets/ungrid_button.dart';
import '../widgets/ungrid_scaffold.dart';
import '../game/levels/level_repository.dart';
import '../services/haptic_service.dart';
import '../services/progress_service.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';
import 'rewards_screen.dart';

/// L'accueil. Trois informations, une action : on joue en un geste.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.progress,
    required this.haptics,
  });

  final LevelRepository repository;
  final ProgressService progress;
  final HapticService haptics;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Le premier niveau à jouer est prêt avant même que le joueur appuie.
    widget.repository.prefetchAround(widget.progress.highestUnlockedLevel);
    _announceResetIfNeeded();
  }

  /// Après la fin du catalogue, le bouton permet de rejouer le dernier défi.
  int get _currentLevel => widget.repository.lastLevel == null
      ? widget.progress.highestUnlockedLevel
      : widget.progress.highestUnlockedLevel.clamp(
          1,
          widget.repository.lastLevel!,
        );

  bool get _campaignComplete =>
      widget.repository.lastLevel != null &&
      widget.progress.highestUnlockedLevel > widget.repository.lastLevel!;

  void _announceResetIfNeeded() {
    final newCampaign = widget.progress.startedNewCampaign;
    if (!widget.progress.wasResetForNewLevels && !newCampaign) return;
    widget.progress.acknowledgeReset();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(
            newCampaign
                ? 'New challenge campaign. Your previous save has been kept separately.'
                : 'New levels: the puzzles changed, so progress and records were reset.',
          ),
        ),
      );
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: GameTiming.screenTransition,
        reverseTransitionDuration: GameTiming.screenTransition,
        pageBuilder: (context, animation, _) =>
            FadeTransition(opacity: animation, child: screen),
      ),
    );
    if (mounted) setState(() {});
  }

  void _play() => _open(
    GameScreen(
      levelId: _currentLevel,
      repository: widget.repository,
      progress: widget.progress,
      haptics: widget.haptics,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final level = _currentLevel;
    final completed = widget.progress.completedCount();

    return UngridScaffold(
      child: Column(
        children: [
          const Spacer(flex: 3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Image.asset(
              'assets/images/logo.png',
              filterQuality: FilterQuality.medium,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _campaignComplete ? 'CAMPAIGN COMPLETE' : 'LEVEL $level',
            style: textTheme.labelLarge,
          ),
          const SizedBox(height: 14),
          Text(
            'CHAPTER ${(level - 1) ~/ 10 + 1} · ${widget.progress.chapterCleared((level - 1) ~/ 10 + 1)}/10 SOLVED',
            style: textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 210,
            child: LinearProgressIndicator(
              value: widget.progress.chapterCleared((level - 1) ~/ 10 + 1) / 10,
              color: UngridColors.success,
              backgroundColor: UngridColors.surface,
              borderRadius: BorderRadius.circular(6),
              minHeight: 6,
            ),
          ),
          const Spacer(flex: 2),
          UngridButton(
            label: _campaignComplete ? 'REPLAY' : 'PLAY',
            onPressed: _play,
            horizontalPadding: 64,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _open(RewardsScreen(progress: widget.progress)),
            child: const Text('REWARDS'),
          ),
          const Spacer(flex: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FooterAction(
                label: 'LEVELS',
                onPressed: () => _open(
                  LevelSelectScreen(
                    repository: widget.repository,
                    progress: widget.progress,
                    haptics: widget.haptics,
                  ),
                ),
              ),
              const SizedBox(width: 28),
              _FooterAction(
                icon: Icons.settings_rounded,
                onPressed: () => _open(
                  SettingsScreen(
                    progress: widget.progress,
                    haptics: widget.haptics,
                    repository: widget.repository,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (completed > 0)
            Text(
              '$completed LEVEL${completed > 1 ? 'S' : ''} CLEARED',
              style: textTheme.labelLarge,
            ),
          const SizedBox(height: 26),
        ],
      ),
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({this.label, this.icon, required this.onPressed});

  final String? label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: label != null
          ? Text(label!, style: Theme.of(context).textTheme.labelLarge)
          : Icon(icon, color: UngridColors.onBackgroundFaint, size: 22),
    );
  }
}
