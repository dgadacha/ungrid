import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/constants.dart';
import '../../app/theme.dart';
import '../models/direction.dart';

/// Dessin d'un bloc : la brique visuelle du jeu.
///
/// Tout est tracé, rien n'est importé. Un aplat de couleur, un arrondi, une
/// flèche épaisse — ni dégradé, ni reflet, ni relief. Le rendu reste net à
/// n'importe quelle taille de grille et pivote sans qu'un éclairage vienne
/// trahir la rotation.
///
/// Les objets `Paint` sont construits une fois et réutilisés : à soixante
/// images par seconde et vingt blocs à l'écran, en allouer à chaque passage se
/// paie tout de suite.
class BlockPainter {
  BlockPainter();

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _shadow = Paint()
    ..isAntiAlias = true
    ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 2);
  final Paint _arrowFill = Paint()..isAntiAlias = true;
  final Paint _arrowStroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final Paint _cellFill = Paint()
    ..isAntiAlias = true
    ..color = UngridColors.surface;
  final Paint _stopRing = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..color = UngridColors.onBackgroundFaint;
  final Paint _stopDot = Paint()
    ..isAntiAlias = true
    ..color = UngridColors.onBackgroundFaint;

  /// Contour de la flèche, en coordonnées normalisées autour de son centre,
  /// pointant vers la droite. Les quatre directions ne sont que des rotations
  /// de cette même forme.
  static final Path _arrowPath = Path()
    ..moveTo(-0.46, -0.13)
    ..lineTo(0.02, -0.13)
    ..lineTo(0.02, -0.33)
    ..lineTo(0.47, 0)
    ..lineTo(0.02, 0.33)
    ..lineTo(0.02, 0.13)
    ..lineTo(-0.46, 0.13)
    ..close();

  /// Case vide : un ton au-dessus du fond, et rien de plus. Elle situe la
  /// grille sans jamais concurrencer les blocs.
  void paintEmptyCell(Canvas canvas, Rect cell) {
    final rect = cell.deflate(cell.width * GameMetrics.blockInsetRatio);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(rect.width * GameMetrics.blockRadiusRatio),
      ),
      _cellFill,
    );
  }

  /// Tuile d'arrêt : un anneau et un point, au centre de la case.
  ///
  /// Ni aplat ni arrondi : rien qui puisse passer pour un bloc ou pour un
  /// bouton. Le signe est petit, dans le gris du fond, et ne prend la parole
  /// que si on le cherche — ce qui suffit, puisqu'il ne se touche pas.
  void paintStopTile(Canvas canvas, Rect cell) {
    final center = cell.center;
    final radius = cell.width * 0.17;
    _stopRing.strokeWidth = (cell.width * 0.045).clamp(1.2, 3.0);
    canvas.drawCircle(center, radius, _stopRing);
    canvas.drawCircle(center, cell.width * 0.05, _stopDot);
  }

  /// Le même repère, quand un bloc est posé dessus.
  ///
  /// Le bloc recouvre le centre : on souligne alors la case, dans la marge
  /// que le bloc laisse libre. L'information reste lisible sans rien ajouter
  /// par-dessus le bloc.
  void paintOccupiedStopTile(Canvas canvas, Rect cell) {
    final rect = cell.deflate(cell.width * GameMetrics.blockInsetRatio * 0.35);
    _stopRing.strokeWidth = (cell.width * 0.03).clamp(1.0, 2.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(rect.width * GameMetrics.blockRadiusRatio),
      ),
      _stopRing,
    );
  }

  /// Le repère reste visible autour du bloc posé sur la rotation.
  void paintRotationTile(Canvas canvas, Rect cell, {bool occupied = false}) {
    final paint = Paint()
      ..color = const Color(0xFF9CE7EE)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    final r = cell.width * (occupied ? .46 : .21);
    final c = cell.center;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -1.5707963267948966,
      4.71238898038469,
      false,
      paint,
    );
    final tip = Offset(c.dx - r, c.dy);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx - r * .30, tip.dy + r * .35)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(tip.dx + r * .30, tip.dy + r * .35),
      paint,
    );
  }

  /// Un losange fendu distingue la tuile fragile même sans sa couleur.
  void paintFragileStopTile(Canvas canvas, Rect cell, {bool occupied = false}) {
    final paint = Paint()
      ..color = const Color(0xFFF8C471)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final r = cell.width * (occupied ? .46 : .19);
    final c = cell.center;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r, c.dy)
      ..close();
    canvas.drawPath(path, paint);
    if (!occupied) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx + r * .2, c.dy - r)
          ..lineTo(c.dx - r * .2, c.dy)
          ..lineTo(c.dx + r * .2, c.dy + r),
        paint,
      );
    }
  }

  /// Dessine un bloc dans la case donnée.
  ///
  /// [scale] sert à l'enfoncement sous le doigt, [opacity] à la disparition en
  /// fin de sortie.
  void paintBlock(
    Canvas canvas,
    Rect cell,
    Direction direction,
    Color color, {
    double scale = 1,
    double opacity = 1,
    Offset offset = Offset.zero,
  }) {
    var rect = cell
        .deflate(cell.width * GameMetrics.blockInsetRatio)
        .shift(offset);
    if (scale != 1) {
      rect = Rect.fromCenter(
        center: rect.center,
        width: rect.width * scale,
        height: rect.height * scale,
      );
    }

    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.width * GameMetrics.blockRadiusRatio),
    );

    // Une ombre à peine perceptible : juste de quoi décoller le bloc du fond.
    _shadow.color = const Color(0xFF000000).withValues(alpha: 0.12 * opacity);
    canvas.drawRRect(rrect.shift(const Offset(0, 2)), _shadow);

    _fill.color = opacity >= 1 ? color : color.withValues(alpha: opacity);
    canvas.drawRRect(rrect, _fill);

    _paintArrow(canvas, rect, direction, opacity);
  }

  void _paintArrow(
    Canvas canvas,
    Rect rect,
    Direction direction,
    double opacity,
  ) {
    final size = rect.width * GameMetrics.arrowSizeRatio;
    final center = rect.center;
    final color = opacity >= 1
        ? UngridColors.arrow
        : UngridColors.arrow.withValues(alpha: opacity);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(direction.angle);
    canvas.scale(size);

    _arrowFill.color = color;
    // Le même contour en trait arrondi adoucit les angles : une flèche à
    // pointes vives paraît agressive à cette taille.
    _arrowStroke
      ..color = color
      ..strokeWidth = 0.14;

    canvas.drawPath(_arrowPath, _arrowStroke);
    canvas.drawPath(_arrowPath, _arrowFill);
    canvas.restore();
  }
}
