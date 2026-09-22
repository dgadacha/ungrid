import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/levels/level_repository.dart';
import '../services/haptic_service.dart';
import '../services/progress_service.dart';
import '../widgets/ungrid_scaffold.dart';
import 'debug_generation_screen.dart';

/// Réglages. Le strict nécessaire, sans sous-menu.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.progress,
    required this.haptics,
    required this.repository,
  });

  final ProgressService progress;
  final HapticService haptics;
  final LevelRepository repository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _haptics = widget.progress.hapticsEnabled;

  Future<void> _toggleHaptics(bool value) async {
    setState(() => _haptics = value);
    widget.haptics.enabled = value;
    await widget.progress.setHapticsEnabled(value);
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: UngridColors.surface,
        title: const Text('Effacer la progression ?',
            style: TextStyle(color: UngridColors.onBackground)),
        content: const Text(
          'Les niveaux terminés et les records seront perdus.',
          style: TextStyle(color: UngridColors.onBackgroundSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await widget.progress.resetProgress();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return UngridScaffold(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      'RÉGLAGES',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SwitchListTile.adaptive(
              value: _haptics,
              onChanged: _toggleHaptics,
              contentPadding: const EdgeInsets.symmetric(horizontal: 28),
              title: Text('VIBRATIONS', style: textTheme.labelLarge),
              activeThumbColor: UngridColors.onBackground,
              activeTrackColor: UngridColors.success,
            ),
            const Divider(height: 34, indent: 28, endIndent: 28),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 28),
              onTap: _confirmReset,
              title: Text('EFFACER LA PROGRESSION',
                  style: textTheme.labelLarge?.copyWith(
                    color: UngridColors.danger,
                  )),
              subtitle: Text(
                'Niveau ${widget.progress.highestUnlockedLevel}'
                ' · ${widget.progress.completedCount()} terminés',
                style: textTheme.bodyMedium,
              ),
            ),
            const Spacer(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 28),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DebugGenerationScreen(
                    repository: widget.repository,
                    progress: widget.progress,
                    haptics: widget.haptics,
                  ),
                ),
              ),
              title: Text('GÉNÉRATION', style: textTheme.labelLarge),
              subtitle: Text('Analyse et réglage des niveaux',
                  style: textTheme.bodyMedium),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: UngridColors.onBackgroundFaint),
            ),
            const SizedBox(height: 18),
          ],
      ),
    );
  }
}
