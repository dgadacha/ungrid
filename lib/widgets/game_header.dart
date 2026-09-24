import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../app/strings.dart';
import '../app/theme.dart';
import '../game/controllers/game_controller.dart';

/// Formatage du temps de jeu, partagé par le bandeau et les écrans de fin.
String formatPlayTime(Duration duration) {
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Bandeau du haut : niveau, coups restants, temps.
///
/// Les coups restants sont l'information principale — c'est d'eux que dépend
/// la partie. Le temps est là pour la performance, en retrait.
class GameHeader extends StatefulWidget {
  const GameHeader({
    super.key,
    required this.controller,
    required this.levelId,
    required this.onBack,
    this.bestTime,
  });

  final GameController controller;
  final int levelId;
  final VoidCallback onBack;

  /// Meilleur temps déjà réalisé, affiché discrètement comme objectif.
  final Duration? bestTime;

  @override
  State<GameHeader> createState() => _GameHeaderState();
}

class _GameHeaderState extends State<GameHeader> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Le chronomètre s'affiche à la seconde : quatre rafraîchissements par
    // seconde suffisent, et n'entraînent pas la grille avec eux.
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final controller = widget.controller;

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(
                  PhosphorIconsBold.arrowLeft,
                  color: UngridColors.onBackground,
                ),
                splashRadius: 24,
              ),
              Expanded(
                child: Text(
                  Strings.of(context).level(widget.levelId),
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) =>
                          _MovesLeft(controller: controller),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topRight,
                    child: _TimePanel(
                      elapsed: controller.elapsed,
                      best: widget.bestTime,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Coups restants. Le nombre sursaute à chaque coup joué, et passe à l'alerte
/// quand la fin approche.
class _MovesLeft extends StatelessWidget {
  const _MovesLeft({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final pressure = controller.pressure;
    final color = pressure >= 0.75
        ? UngridColors.danger
        : pressure > 0
        ? UngridColors.accent
        : UngridColors.onBackground;

    // Le sursaut suit le changement de valeur ; la tension ajoute un battement
    // continu quand il ne reste presque plus rien.
    final beat = pressure == 0
        ? 0.0
        : math.sin(controller.nowMs / 380) * 0.035 * pressure;
    final scale = 1 + controller.movesPulse * 0.22 + beat;

    final strings = Strings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.movesLeft, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 2),
        Transform.scale(
          alignment: Alignment.centerLeft,
          scale: scale,
          child: Text(
            '${controller.movesLeft}',
            style: TextStyle(
              fontSize: 36,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimePanel extends StatelessWidget {
  const _TimePanel({required this.elapsed, required this.best});

  final Duration elapsed;
  final Duration? best;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final strings = Strings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(strings.time, style: textTheme.labelLarge),
        const SizedBox(height: 2),
        Text(
          formatPlayTime(elapsed),
          style: const TextStyle(
            fontSize: 26,
            height: 1.5,
            fontWeight: FontWeight.w800,
            color: UngridColors.onBackground,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        if (best != null)
          Text(
            strings.best(formatPlayTime(best!)),
            style: textTheme.labelLarge?.copyWith(fontSize: 10),
          ),
      ],
    );
  }
}
