import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../app/strings.dart';
import '../app/theme.dart';
import '../services/progress_service.dart';
import '../widgets/ungrid_scaffold.dart';

/// Les récompenses sont connues d'avance et ne changent aucune règle.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key, required this.progress});
  final ProgressService progress;
  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    const thresholds = [0, 1, 3, 5];
    return UngridScaffold(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(PhosphorIconsBold.arrowLeft),
              ),
              Expanded(
                child: Text(
                  Strings.of(context).collection,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  '${p.completedChapters} / 10 CHAPTER MEDALS',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var chapter = 1; chapter <= 10; chapter++)
                      Tooltip(
                        message:
                            Strings.of(context).chapterMastery(chapter, p.chapterCleared(chapter), p.chapterMastered(chapter)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhosphorIconsBold.medal,
                              size: 36,
                              color: p.chapterMastered(chapter) == 10
                                  ? const Color(0xFFF8C471)
                                  : p.chapterCleared(chapter) == 10
                                  ? UngridColors.success
                                  : UngridColors.surface,
                            ),
                            Text('$chapter'),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(Strings.of(context).rewardsRule),
                const SizedBox(height: 24),
                for (
                  var palette = 0;
                  palette < UngridColors.palettes.length;
                  palette++
                ) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            UngridColors.paletteNames[palette],
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final color
                                  in UngridColors.palettes[palette].take(4))
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            palette == 0
                                ? Strings.of(context).alwaysAvailable
                                : '${thresholds[palette]} chapter medal${thresholds[palette] > 1 ? 's' : ''}',
                          ),
                          TextButton(
                            onPressed: p.unlockedPalettes.contains(palette)
                                ? () async {
                                    await p.selectPalette(palette);
                                    if (mounted) setState(() {});
                                  }
                                : null,
                            child: Text(
                              p.paletteIndex == palette
                                  ? Strings.of(context).equipped
                                  : p.unlockedPalettes.contains(palette)
                                  ? Strings.of(context).equip
                                  : Strings.of(context).locked,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
