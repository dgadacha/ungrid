import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Le nom du jeu, avec le I remplacé par une flèche.
///
/// Dessiné plutôt qu'importé : le titre suit alors la palette, reste net à
/// toutes les tailles, et ne dépend d'aucun fichier.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.fontSize = 52});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: fontSize * 0.01,
      height: 1,
      color: UngridColors.onBackground,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('UNGR', style: style),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: fontSize * 0.045),
          child: CustomPaint(
            // La flèche dépasse des lettres : c'est elle qui porte le nom.
            size: Size(fontSize * 0.60, fontSize * 1.10),
            painter: _ArrowLetterPainter(),
          ),
        ),
        Text('D', style: style),
      ],
    );
  }
}

/// Le « I » du titre : une flèche vers le haut, du cyan au bleu.
class _ArrowLetterPainter extends CustomPainter {
  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Proportions : une tête large et courte, une tige étroite.
    const headRatio = 0.46;
    const stemRatio = 0.50;
    final headBottom = height * headRatio;
    final stemHalf = width * stemRatio / 2;
    final center = width / 2;

    final path = Path()
      ..moveTo(center, height * 0.05)
      ..lineTo(width * 0.95, headBottom)
      ..lineTo(center + stemHalf, headBottom)
      ..lineTo(center + stemHalf, height * 0.95)
      ..lineTo(center - stemHalf, height * 0.95)
      ..lineTo(center - stemHalf, headBottom)
      ..lineTo(width * 0.05, headBottom)
      ..close();

    // Le seul dégradé du jeu : il signe le nom, nulle part ailleurs.
    final shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [UngridColors.accent, Color(0xFF2563EB)],
    ).createShader(Offset.zero & size);

    _fill.shader = shader;
    _stroke
      ..shader = shader
      ..strokeWidth = width * 0.17;

    // Le contour arrondi adoucit la pointe et les épaules.
    canvas.drawPath(path, _stroke);
    canvas.drawPath(path, _fill);
  }

  @override
  bool shouldRepaint(_ArrowLetterPainter oldDelegate) => false;
}
