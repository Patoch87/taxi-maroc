import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Étoile à huit branches (khatam) : deux carrés superposés, l'un tourné de 45°.
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

/// Logo de Taxi Maroc : étoile khatam verte, liseré sable, enseigne de taxi rouge marquée d'un « T ».
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Taxi Maroc',
        image: true,
        child: SizedBox.square(dimension: size, child: const CustomPaint(painter: AppLogoPainter())),
      );
}

class AppLogoPainter extends CustomPainter {
  const AppLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    final r = s / 2;
    final fill = Paint()..isAntiAlias = true;

    // Étoile verte, puis étoile intérieure sable et filet vert : le motif du zellige.
    canvas.drawPath(khatamPath(c, r), fill..color = AppColors.moroccoGreen);
    canvas.drawPath(khatamPath(c, r * .78), fill..color = AppColors.sand);
    canvas.drawPath(
        khatamPath(c, r * .68),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1, s * .03)
          ..color = AppColors.moroccoGreen);

    // Enseigne lumineuse du toit d'un petit taxi : trapèze rouge arrondi.
    final w = s * .5, h = s * .32;
    final top = c.dy - h / 2;
    final sign = Path()
      ..moveTo(c.dx - w * .36, top)
      ..lineTo(c.dx + w * .36, top)
      ..lineTo(c.dx + w / 2, top + h)
      ..lineTo(c.dx - w / 2, top + h)
      ..close();
    canvas.drawPath(
        sign,
        Paint()
          ..color = AppColors.taxiRed
          ..style = PaintingStyle.fill
          ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(
        sign,
        Paint()
          ..color = AppColors.taxiRed
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .05
          ..strokeJoin = StrokeJoin.round);

    // « T » blanc
    final white = Paint()..color = Colors.white;
    final bar = s * .055;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, top + h * .26), width: w * .48, height: bar),
            Radius.circular(bar / 2)),
        white);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(c.dx - bar / 2, top + h * .2, bar, h * .64), Radius.circular(bar / 2)),
        white);
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
