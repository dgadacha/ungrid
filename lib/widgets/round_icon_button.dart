import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Bouton rond de l'interface de jeu.
///
/// Discret par défaut, franchement éteint quand l'action n'est pas disponible.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.size = 54,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.35,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: UngridColors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: size * 0.44,
                  color: UngridColors.onBackground),
            ),
            if (label != null) ...[
              const SizedBox(height: 7),
              Text(
                label!,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
