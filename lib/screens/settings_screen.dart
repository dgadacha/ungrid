import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../app/constants.dart';
import '../app/strings.dart';
import '../app/theme.dart';
import '../game/levels/level_repository.dart';
import '../services/haptic_service.dart';
import '../services/progress_service.dart';
import '../widgets/ungrid_scaffold.dart';
import 'debug_generation_screen.dart';
import 'playtest_screen.dart';

/// Réglages. Le strict nécessaire, sans sous-menu.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.progress,
    required this.haptics,
    required this.repository,
    this.onLanguageChanged,
    this.onBackgroundChanged,
  });

  final ProgressService progress;
  final HapticService haptics;
  final LevelRepository repository;

  /// Appelé quand le joueur choisit une autre langue.
  final ValueChanged<AppLanguage>? onLanguageChanged;

  /// Appelé quand le joueur choisit une autre couleur de fond.
  final ValueChanged<UngridBackground>? onBackgroundChanged;

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
        title: Text(
          Strings.of(context).resetQuestion,
          style: const TextStyle(color: UngridColors.onBackground),
        ),
        content: Text(
          Strings.of(context).resetWarning,
          style: const TextStyle(color: UngridColors.onBackgroundSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(Strings.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(Strings.of(context).reset),
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
    final strings = Strings.of(context);

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
                  icon: const Icon(
                    PhosphorIconsBold.arrowLeft,
                    color: UngridColors.onBackground,
                  ),
                  splashRadius: 24,
                ),
                Expanded(
                  child: Text(
                    strings.settings,
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
            title: Text(strings.haptics, style: textTheme.labelLarge),
            activeThumbColor: UngridColors.onBackground,
            activeTrackColor: UngridColors.success,
          ),
          const Divider(height: 34, indent: 28, endIndent: 28),

          // Les fonds se choisissent à la couleur, pas au nom : une pastille
          // dit immédiatement ce que le plateau deviendra.
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
            child: Text(strings.backgroundLabel, style: textTheme.labelLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 6),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final choice in UngridBackground.values)
                  _BackgroundChoice(
                    choice: choice,
                    selected: UngridColors.background == choice.background,
                    onTap: () => widget.onBackgroundChanged?.call(choice),
                  ),
              ],
            ),
          ),
          const Divider(height: 34, indent: 28, endIndent: 28),

          // Chaque langue s'annonce dans sa propre langue : c'est le seul
          // réglage qu'on cherche justement quand on ne comprend pas ce qui
          // est affiché.
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
            child: Text(strings.languageLabel, style: textTheme.labelLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 6),
            child: Row(
              children: [
                for (final language in AppLanguage.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _LanguageChoice(
                        label: language.label,
                        selected: strings.language == language,
                        onTap: () => widget.onLanguageChanged?.call(language),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 34, indent: 28, endIndent: 28),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 28),
            onTap: _confirmReset,
            title: Text(
              strings.resetProgress,
              style: textTheme.labelLarge?.copyWith(color: UngridColors.danger),
            ),
            subtitle: Text(
              strings.progressSummary(
                widget.progress.highestUnlockedLevel,
                widget.progress.completedCount(),
              ),
              style: textTheme.bodyMedium,
            ),
          ),
          const Spacer(),
          if (showDeveloperTools) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 28),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlaytestScreen(
                    repository: widget.repository,
                    progress: widget.progress,
                    haptics: widget.haptics,
                  ),
                ),
              ),
              title: Text('PLAYTEST', style: textTheme.labelLarge),
              subtitle: Text(
                'Jump to any level, nothing is saved',
                style: textTheme.bodyMedium,
              ),
              trailing: const Icon(
                PhosphorIconsBold.caretRight,
                color: UngridColors.onBackgroundFaint,
              ),
            ),
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
              title: Text('GENERATION', style: textTheme.labelLarge),
              subtitle: Text(
                'Level analysis and tuning',
                style: textTheme.bodyMedium,
              ),
              trailing: const Icon(
                PhosphorIconsBold.caretRight,
                color: UngridColors.onBackgroundFaint,
              ),
            ),
          ],
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

/// Un choix de langue : assez large pour être touché, assez discret pour ne
/// pas passer pour une action de jeu.
class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? UngridColors.accent : UngridColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: UngridColors.onBackground,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Une pastille de fond : la teinte du plateau, et sa nuance de cases vides
/// en son centre.
///
/// Montrer les deux couleurs d'un coup évite d'avoir à essayer pour voir :
/// c'est exactement ce que la grille donnera.
class _BackgroundChoice extends StatelessWidget {
  const _BackgroundChoice({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final UngridBackground choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: choice.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? UngridColors.onBackground
                : UngridColors.onBackground.withValues(alpha: 0.18),
            width: selected ? 3 : 1,
          ),
        ),
        child: Center(
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: choice.surface,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}
