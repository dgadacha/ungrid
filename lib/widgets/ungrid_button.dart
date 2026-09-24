import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Bouton principal du jeu : pastille claire posée sur le bleu.
class UngridButton extends StatelessWidget {
  const UngridButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = true,
    this.horizontalPadding = 54,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  /// Une action secondaire garde le fond bleu et se contente d'un contour.
  final bool filled;

  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    // Bouton principal : clair sur le fond nuit, pour qu'on ne le cherche pas.
    final foreground = filled ? UngridColors.ink : UngridColors.onBackground;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 17,
        ),
        decoration: BoxDecoration(
          color: filled ? UngridColors.onBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: filled
              ? null
              : Border.all(color: UngridColors.onBackgroundFaint, width: 2),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: const Color(0xFF000000).withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon!, size: 19, color: foreground),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
