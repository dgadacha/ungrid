import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Une particule de la gerbe de victoire.
class ClearParticle {
  const ClearParticle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
  });

  final double angle;
  final double distance;
  final double size;
  final double delay;
}

/// Petite gerbe jouée quand la grille se vide.
///
/// Elle est fabriquée une fois, sans hasard à l'exécution : la victoire doit
/// avoir toujours la même allure.
class ClearEffect {
  ClearEffect({int count = 18, int seed = 7}) : particles = _build(count, seed);

  final List<ClearParticle> particles;

  static List<ClearParticle> _build(int count, int seed) {
    final random = math.Random(seed);
    return [
      for (var i = 0; i < count; i++)
        ClearParticle(
          angle: (i / count) * math.pi * 2 + random.nextDouble() * 0.3,
          distance: 0.30 + random.nextDouble() * 0.38,
          size: 3.5 + random.nextDouble() * 4,
          delay: random.nextDouble() * 0.18,
        ),
    ];
  }

  final Paint _paint = Paint()..isAntiAlias = true;

  /// [progress] va de 0 à 1 sur la durée de l'impulsion.
  void paint(Canvas canvas, Rect board, double progress) {
    if (progress <= 0 || progress >= 1) return;
    final center = board.center;
    final radius = board.width / 2;

    for (final particle in particles) {
      final local = ((progress - particle.delay) / (1 - particle.delay)).clamp(
        0.0,
        1.0,
      );
      if (local <= 0) continue;

      final eased = 1 - math.pow(1 - local, 3).toDouble();
      final distance = radius * particle.distance * eased;
      final position =
          center +
          Offset(math.cos(particle.angle), math.sin(particle.angle)) * distance;

      _paint.color = UngridColors.ink.withValues(alpha: (1 - local) * 0.55);
      canvas.drawCircle(position, particle.size * (1 - local * 0.5), _paint);
    }
  }
}
