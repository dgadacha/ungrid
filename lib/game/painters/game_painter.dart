import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../controllers/game_controller.dart';
import '../animations/block_animations.dart';
import 'block_painter.dart';
import 'board_layout.dart';
import 'effects_painter.dart';

/// Dessine la grille, les blocs et leurs animations.
///
/// Une seule passe de peinture pour toute la partie : les blocs en cours de
/// sortie sont tracés au même titre que les autres, simplement décalés hors du
/// board. Un bloc ne disparaît jamais d'un coup, il s'en va.
class GamePainter extends CustomPainter {
  GamePainter({
    required this.controller,
    required this.nowMs,
    required this.blocks,
    required this.effect,
    required String bonkLabel,
  })  : _bonk = TextPainter(
          text: TextSpan(
            text: bonkLabel,
            style: const TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: UngridColors.onBackground,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
        super(repaint: controller);

  final Paint _hintPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;

  final TextPainter _bonk;

  final GameController controller;

  /// Horloge partagée par toutes les animations de la frame.
  final int nowMs;

  final BlockPainter blocks;
  final ClearEffect effect;

  @override
  void paint(Canvas canvas, Size size) {
    final level = controller.level;
    final layout = BoardLayout.fit(size, level.columns, level.rows);
    if (layout.cellSize <= 0) return;

    final pulse = controller.clearPulse;
    if (pulse > 0) {
      // Courte respiration du board quand la grille se vide.
      final scale = 1 + math.sin(pulse * math.pi) * 0.02;
      canvas.save();
      canvas.translate(layout.rect.center.dx, layout.rect.center.dy);
      canvas.scale(scale);
      canvas.translate(-layout.rect.center.dx, -layout.rect.center.dy);
    }

    for (var y = 0; y < level.rows; y++) {
      for (var x = 0; x < level.columns; x++) {
        blocks.paintEmptyCell(canvas, layout.cellRect(x, y));
      }
    }

    // Les tuiles se dessinent sous les blocs : une case occupée garde son
    // repère, porté par le liseré plutôt que par le point central.
    for (final tile in controller.engine.activeStopTiles) {
      final cell = layout.cellRect(tile.x, tile.y);
      if (controller.engine.isRotationAt(tile.x, tile.y)) {
        blocks.paintRotationTile(
          canvas,
          cell,
          occupied: controller.engine.blockAt(tile.x, tile.y) != null,
        );
      } else if (controller.engine.isFragileStopAt(tile.x, tile.y)) {
        blocks.paintFragileStopTile(
          canvas,
          cell,
          occupied: controller.engine.blockAt(tile.x, tile.y) != null,
        );
      } else if (controller.engine.blockAt(tile.x, tile.y) == null) {
        blocks.paintStopTile(canvas, cell);
      } else {
        blocks.paintOccupiedStopTile(canvas, cell);
      }
    }

    final blocked = controller.blockedFeedback;
    final press = controller.pressFeedback;
    final hinted = controller.hintedBlockId;
    final animated = controller.animatedBlockIds;

    for (final block in controller.engine.remainingBlocks) {
      // Un bloc en cours de déplacement est dessiné par son animation, à sa
      // position interpolée : le dessiner ici en plus le dédoublerait.
      if (animated.contains(block.id)) continue;

      var offset = Offset.zero;
      var scale = 1.0;

      if (blocked != null && blocked.block.id == block.id) {
        // Un aller-retour bref dans la direction refusée : le bloc essaie,
        // bute, revient. Aucun texte n'est nécessaire pour comprendre.
        final travel =
            math.sin(blocked.progress(nowMs) * math.pi) *
            layout.cellSize *
            0.16;
        offset = Offset(
          block.direction.dx * travel,
          block.direction.dy * travel,
        );
      }

      if (press != null && press.blockId == block.id) {
        scale = 1 - math.sin(press.progress(nowMs) * math.pi) * 0.06;
      }

      final cell = layout.cellRect(block.x, block.y);

      if (hinted == block.id) _paintHint(canvas, cell);

      blocks.paintBlock(
        canvas,
        cell,
        block.direction,
        UngridColors.blockFor(block.id),
        offset: offset,
        scale: scale,
      );
    }

    for (final motion in controller.motions) {
      _paintMotion(canvas, layout, motion);
    }

    for (final tile in level.rotationTiles) {
      final occupant = controller.engine.blockAt(tile.x, tile.y);
      if (occupant != null && !animated.contains(occupant.id)) {
        blocks.paintRotationBadge(canvas, layout.cellRect(tile.x, tile.y));
      }
    }

    if (blocked != null) _paintBonk(canvas, layout, blocked);

    if (pulse > 0) {
      canvas.restore();
      effect.paint(canvas, layout.rect, 1 - pulse);
    }
  }

  /// Dessine un bloc en mouvement, entre deux cases.
  ///
  /// Le trajet est le même pour une sortie, un glissement ou un retour en
  /// arrière : seules changent les extrémités et la disparition en bout de
  /// course.
  void _paintMotion(Canvas canvas, BoardLayout layout, BlockMotion motion) {
    final t = motion.progress(nowMs);
    final eased = 1 - math.pow(1 - t, 3).toDouble();

    final x = motion.fromX + (motion.toX - motion.fromX) * eased;
    final y = motion.fromY + (motion.toY - motion.fromY) * eased;

    final cell = Rect.fromLTWH(
      layout.rect.left + x * layout.cellSize,
      layout.rect.top + y * layout.cellSize,
      layout.cellSize,
      layout.cellSize,
    );

    var opacity = 1.0;
    if (motion.fadeOut && t > 0.7) opacity = 1 - (t - 0.7) / 0.3;
    if (motion.fadeIn && t < 0.3) opacity = t / 0.3;

    blocks.paintBlock(
      canvas,
      cell,
      motion.direction,
      UngridColors.blockFor(motion.blockId),
      opacity: opacity.clamp(0.0, 1.0),
      scale: motion.fadeOut ? 1 - t * 0.06 : 1,
    );
  }

  /// Halo battant autour du bloc conseillé. Il désigne, il ne joue pas : le
  /// coup reste celui du joueur.
  void _paintHint(Canvas canvas, Rect cell) {
    final beat = 0.5 + 0.5 * math.sin(nowMs / 260);
    final rect = cell.deflate(cell.width * 0.02 - beat * 3);
    _hintPaint
      ..color = UngridColors.onBackground.withValues(alpha: 0.35 + beat * 0.45)
      ..strokeWidth = 3 + beat * 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.26)),
      _hintPaint,
    );
  }

  /// Étiquette du coup refusé : elle monte et s'efface au-dessus du bloc.
  void _paintBonk(Canvas canvas, BoardLayout layout, BlockedFeedback blocked) {
    final t = blocked.labelProgress(nowMs);
    if (t >= 1) return;

    final cell = layout.cellRect(blocked.block.x, blocked.block.y);
    final rise = layout.cellSize * 0.42 * Curves.easeOutCubic.transform(t);
    final opacity = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;

    canvas.save();
    canvas.translate(
      cell.center.dx - _bonk.width / 2,
      cell.top - _bonk.height * 0.6 - rise,
    );
    canvas.saveLayer(
      Offset.zero & Size(_bonk.width, _bonk.height),
      Paint()
        ..colorFilter = ColorFilter.mode(
          const Color(0xFFFFFFFF).withValues(alpha: opacity.clamp(0.0, 1.0)),
          BlendMode.modulate,
        ),
    );
    _bonk.paint(canvas, Offset.zero);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(GamePainter oldDelegate) => true;
}
