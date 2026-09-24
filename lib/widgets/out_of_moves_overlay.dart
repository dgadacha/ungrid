import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../app/strings.dart';
import '../app/theme.dart';
import 'ungrid_button.dart';

/// Écran de fin de partie : plus de coups, des blocs encore là.
///
/// Volontairement nu. Le joueur doit pouvoir relancer sans rien lire.
class OutOfMovesOverlay extends StatefulWidget {
  const OutOfMovesOverlay({
    super.key,
    required this.remainingBlocks,
    required this.onRetry,
    this.onExtraMoves,
    this.onUndo,
    this.extraMovesAmount = 3,
  });

  final int remainingBlocks;
  final VoidCallback onRetry;
  final VoidCallback? onUndo;

  /// Proposé seulement quand une récompense est réellement disponible : pas de
  /// bouton mort en attendant la régie publicitaire.
  final VoidCallback? onExtraMoves;

  final int extraMovesAmount;

  @override
  State<OutOfMovesOverlay> createState() => _OutOfMovesOverlayState();
}

class _OutOfMovesOverlayState extends State<OutOfMovesOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final strings = Strings.of(context);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final entrance = Curves.easeOutCubic.transform(_animation.value);
        return Opacity(
          opacity: entrance,
          child: Container(
            // Le plateau reste visible derrière : le joueur voit ce qu'il lui
            // restait à faire.
            color: UngridColors.background.withValues(alpha: 0.88),
            child: Center(
              child: Transform.scale(
                scale: 0.94 + entrance * 0.06,
                child: child,
              ),
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(strings.outOfMoves, style: textTheme.displayMedium),
          const SizedBox(height: 12),
          Text(
            strings.blocksLeft(widget.remainingBlocks),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          if (widget.onUndo != null) ...[
            UngridButton(
              label: strings.undoMove,
              icon: PhosphorIconsBold.arrowCounterClockwise,
              onPressed: widget.onUndo!,
            ),
            const SizedBox(height: 14),
          ],
          UngridButton(
            label: strings.retry,
            icon: PhosphorIconsBold.arrowClockwise,
            onPressed: widget.onRetry,
          ),
          if (widget.onExtraMoves != null) ...[
            const SizedBox(height: 14),
            UngridButton(
              label: strings.extraMoves(widget.extraMovesAmount),
              icon: PhosphorIconsBold.playCircle,
              filled: false,
              onPressed: widget.onExtraMoves!,
            ),
          ],
        ],
      ),
    );
  }
}
