import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/constants.dart';
import '../../app/theme.dart';
import '../models/direction.dart';

/// Dessin d'un bloc : la brique visuelle du jeu.
///
/// Tout est tracé, rien n'est importé. Un aplat de couleur, un arrondi, une
/// flèche épaisse et un relief discret, sans dégradé. Le rendu reste net à
/// n'importe quelle taille de grille et pivote sans qu'un éclairage vienne
/// trahir la rotation.
///
/// Les objets `Paint` sont construits une fois et réutilisés : à soixante
/// images par seconde et vingt blocs à l'écran, en allouer à chaque passage se
/// paie tout de suite.
class BlockPainter {
  BlockPainter();

  final TextPainter _iconPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  void _paintIcon(
    Canvas canvas,
    IconData icon,
    Offset center,
    double size,
    Color color,
  ) {
    _iconPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: size,
        height: 1,
        color: color,
      ),
    );
    _iconPainter.layout();
    _iconPainter.paint(
      canvas,
      center - Offset(_iconPainter.width / 2, _iconPainter.height / 2),
    );
  }

  void dispose() => _iconPainter.dispose();

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _rim = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final Paint _shadow = Paint()
    ..isAntiAlias = true
    ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 2);

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
    if (occupied) {
      final rect = cell.deflate(cell.width * GameMetrics.blockInsetRatio * .35);
      paint.strokeWidth = (cell.width * .022).clamp(1.0, 1.6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(rect.width * GameMetrics.blockRadiusRatio),
        ),
        paint,
      );
      return;
    }
    _paintIcon(
      canvas,
      PhosphorIconsBold.arrowClockwise,
      cell.center,
      cell.width * .48,
      const Color(0xFF9CE7EE),
    );
  }

  /// Petit repère de tuile, séparé de la flèche de déplacement.
  void paintRotationBadge(Canvas canvas, Rect cell) {
    final size = cell.width * .28;
    final center = Offset(
      cell.right - cell.width * .13,
      cell.top + cell.width * .13,
    );
    canvas.drawCircle(
      center,
      size * .5,
      Paint()..color = const Color(0xFF2C3E50),
    );
    paintRotationTile(
      canvas,
      Rect.fromCenter(center: center, width: size * 1.35, height: size * 1.35),
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

    // Une tranche de deux pixels, contenue dans le bloc : la face reste unie.
    final depth = (rect.width * .035).clamp(1.2, 2.5) * scale;
    final baseColor = Color.lerp(color, const Color(0xFF172B3A), .20)!;
    _fill.color = baseColor.withValues(alpha: opacity);
    canvas.drawRRect(rrect, _fill);

    final face = RRect.fromRectAndRadius(
      Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom - depth),
      Radius.circular(rect.width * GameMetrics.blockRadiusRatio),
    );
    _fill.color = color.withValues(alpha: opacity);
    canvas.drawRRect(face, _fill);

    // Fin liseré supérieur ; aucun reflet sur le centre ni sur la flèche.
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * .22),
    );
    _rim.color = Color.lerp(
      color,
      Colors.white,
      .18,
    )!.withValues(alpha: opacity);
    canvas.drawRRect(face.deflate(.5), _rim);
    canvas.restore();

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
    _paintIcon(
      canvas,
      PhosphorIconsFill.arrowFatRight,
      Offset.zero,
      size,
      color,
    );
    canvas.restore();
  }
}
