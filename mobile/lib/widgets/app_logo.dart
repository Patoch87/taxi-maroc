import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Étoile à huit branches (khatam) du zellige : deux carrés superposés, l'un tourné de 45°.
Path khatamPath(Offset c, double r) {
  final path = Path();
  for (final start in [pi / 4, 0.0]) {
    final square = Path();
    for (var i = 0; i < 4; i++) {
      final a = start + i * pi / 2;
      final p = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      i == 0 ? square.moveTo(p.dx, p.dy) : square.lineTo(p.dx, p.dy);
    }
    square.close();
    path.addPath(square, Offset.zero);
  }
  return path;
}

/// Logo de Bab Taxi « Bab, la porte » : arc de porte rouge, route qui s'enfonce vers l'horizon,
/// petit losange vert au sommet. Dessiné sur une grille de 100 x 100.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Bab Taxi',
        image: true,
        child: SizedBox.square(dimension: size, child: const CustomPaint(painter: AppLogoPainter())),
      );
}

class AppLogoPainter extends CustomPainter {
  const AppLogoPainter();

  static const sandLight = Color(0xFFF3EAD7);
  static const road = Color(0xFF0F2A1E);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / 100;
    canvas.save();
    canvas.translate((size.width - 100 * k) / 2, (size.height - 100 * k) / 2);
    canvas.scale(k);
    final paint = Paint()..isAntiAlias = true;

    // Arc extérieur rouge : M22 94 V52 C22 22 36 10 50 10 C64 10 78 22 78 52 V94 Z
    canvas.drawPath(
        Path()
          ..moveTo(22, 94)
          ..lineTo(22, 52)
          ..cubicTo(22, 22, 36, 10, 50, 10)
          ..cubicTo(64, 10, 78, 22, 78, 52)
          ..lineTo(78, 94)
          ..close(),
        paint..color = AppColors.taxiRed);
    // Arc intérieur sable : M31 94 V54 C31 31 40 21 50 21 C60 21 69 31 69 54 V94 Z
    canvas.drawPath(
        Path()
          ..moveTo(31, 94)
          ..lineTo(31, 54)
          ..cubicTo(31, 31, 40, 21, 50, 21)
          ..cubicTo(60, 21, 69, 31, 69, 54)
          ..lineTo(69, 94)
          ..close(),
        paint..color = sandLight);
    // Route : M44 94 L48.5 40 H51.5 L56 94 Z
    canvas.drawPath(
        Path()
          ..moveTo(44, 94)
          ..lineTo(48.5, 40)
          ..lineTo(51.5, 40)
          ..lineTo(56, 94)
          ..close(),
        paint..color = road);
    // Trois tirets au milieu de la route, de plus en plus fins vers l'horizon.
    paint.color = sandLight;
    canvas.drawRect(const Rect.fromLTRB(49.3, 78, 50.7, 86), paint);
    canvas.drawRect(const Rect.fromLTRB(49.45, 63, 50.55, 70), paint);
    canvas.drawRect(const Rect.fromLTRB(49.6, 50, 50.4, 56), paint);
    // Losange vert au sommet : carré de 12 tourné de 45° centré en (50, 8).
    canvas.save();
    canvas.translate(50, 8);
    canvas.rotate(pi / 4);
    canvas.drawRect(const Rect.fromLTRB(-6, -6, 6, 6), paint..color = AppColors.moroccoGreen);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Motif de zellige discret : étoiles à huit branches et losanges, répétés en grille.
class ZelligePainter extends CustomPainter {
  const ZelligePainter({this.color = AppColors.moroccoGreen, this.opacity = .08, this.cell = 36});
  final Color color;
  final double opacity;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: opacity);
    final dot = Paint()..color = color.withValues(alpha: opacity * .9);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var y = 0.0; y < size.height + cell; y += cell) {
      for (var x = 0.0; x < size.width + cell; x += cell) {
        final c = Offset(x + cell / 2, y + cell / 2);
        canvas.drawPath(khatamPath(c, cell * .34), stroke);
        canvas.drawCircle(c, cell * .06, dot);
        // Losange entre quatre étoiles
        final d = Offset(x, y);
        final k = cell * .12;
        canvas.drawPath(
            Path()
              ..moveTo(d.dx, d.dy - k)
              ..lineTo(d.dx + k, d.dy)
              ..lineTo(d.dx, d.dy + k)
              ..lineTo(d.dx - k, d.dy)
              ..close(),
            dot);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ZelligePainter old) => old.color != color || old.opacity != opacity || old.cell != cell;
}

/// Fond décoré de zellige derrière [child].
class Zellige extends StatelessWidget {
  const Zellige({super.key, this.child, this.color = AppColors.moroccoGreen, this.opacity = .08, this.cell = 36});
  final Widget? child;
  final Color color;
  final double opacity;
  final double cell;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: ZelligePainter(color: color, opacity: opacity, cell: cell),
        child: child,
      );
}

/// Petit nom de l'application à côté du logo.
class AppBrand extends StatelessWidget {
  const AppBrand({super.key, required this.title, this.subtitle, this.logoSize = 30, this.fontSize = 17});
  final String title;
  final String? subtitle;
  final double logoSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        AppLogo(size: logoSize),
        const SizedBox(width: 8),
        Flexible(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: fontSize, fontWeight: FontWeight.w900, color: AppColors.moroccoGreen, height: 1.1)),
            if (subtitle != null)
              Text(subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted)),
          ]),
        ),
      ]);
}
