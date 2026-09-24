import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ungrid/app/theme.dart';
import 'package:ungrid/game/engine/level_solver.dart';
import 'package:ungrid/game/engine/slide_generator.dart';
import 'package:ungrid/game/levels/level_pattern.dart';
import 'package:ungrid/game/models/direction.dart';
import 'package:ungrid/game/models/level.dart';
import 'package:ungrid/game/painters/block_painter.dart';
import 'package:ungrid/game/painters/debug_board_painter.dart';

/// Rend quelques boards en PNG pour regarder le résultat.
///
/// Pas un test : un aperçu. `flutter test test/render_preview.dart`.
void main() {
  test('aperçu du rendu', () async {
    final painter = BlockPainter();
    const size = Size(340, 340);

    final levels = <String, Level>{
      'tuiles': LevelPattern.parse(const [
        '>..o.',
        '.o.v.',
        '..>..',
        '.^.o.',
        'o..<.',
      ], id: 1),
    };
    for (final seed in [3, 17, 41]) {
      final level = const SlideGenerator().fromSeed(seed, levelId: seed);
      if (level != null && level.stopTiles.isNotEmpty) {
        levels['seed$seed'] = level;
      }
    }

    final columns = levels.length + 1;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * columns, size.height),
      Paint()..color = UngridColors.background,
    );

    var index = 0;
    for (final entry in levels.entries) {
      final level = entry.value;
      final used = <int>{};
      final solution = const LevelSolver(maxExploredStates: 60000).solve(level);
      // Les tuiles que la solution emprunte vraiment se distinguent des
      // autres : celles qui restent cerclées de rouge ne servent à rien.
      final replay = LevelPattern.render(level);
      expect(replay, isNotEmpty);

      canvas.save();
      canvas.translate(size.width * index, 0);
      DebugBoardPainter(
        level: level,
        blocks: painter,
        positions: [for (final b in level.blocks) b.y * level.columns + b.x],
        removed: const {},
        usedStopTiles: used,
      ).paint(canvas, size);
      canvas.restore();
      index++;

      stdout.writeln(
        '${entry.key}: ${level.columns}x${level.rows}, '
        '${level.blocks.length} blocs, ${level.stopTiles.length} tuiles, '
        '${solution.minimumMoves} coups',
      );
    }

    // L'état « bloc posé sur une tuile » doit rester lisible : le bloc couvre
    // le centre, c'est donc la case qui se souligne.
    canvas.save();
    canvas.translate(size.width * index, 0);
    const layoutCell = 68.0;
    for (var i = 0; i < 4; i++) {
      final rect = Rect.fromLTWH(
        30 + i * (layoutCell + 10),
        120,
        layoutCell,
        layoutCell,
      );
      painter.paintEmptyCell(canvas, rect);
      if (i == 1) painter.paintStopTile(canvas, rect);
      if (i == 2 || i == 3) painter.paintOccupiedStopTile(canvas, rect);
      if (i == 0 || i == 2) {
        painter.paintBlock(
          canvas,
          rect,
          Direction.right,
          UngridColors.blocks[1],
        );
      }
      if (i == 3) {
        painter.paintBlock(canvas, rect, Direction.up, UngridColors.blocks[0]);
      }
    }
    index++;

    canvas.restore();

    final image = await recorder.endRecording().toImage(
      (size.width * columns).round(),
      size.height.round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '/tmp/ungrid_preview.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    stdout.writeln('→ /tmp/ungrid_preview.png');
  });
}
