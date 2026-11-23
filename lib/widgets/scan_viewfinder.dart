import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Bingkai sudut ala viewfinder kamera.
class CornerBracket extends StatelessWidget {
  const CornerBracket({
    super.key,
    this.size = 26,
    this.thickness = 3,
    this.color = SonaColors.primaryContainer,
  });

  final double size;
  final double thickness;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _CornerPainter(thickness: thickness, color: color),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({required this.thickness, required this.color});

  final double thickness;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    const inset = 2.0;

    // Kiri atas
    canvas.drawLine(Offset(inset, inset), Offset(w / 2, inset), paint);
    canvas.drawLine(Offset(inset, inset), Offset(inset, h / 2), paint);
    // Kanan atas
    canvas.drawLine(Offset(w - inset, inset), Offset(w / 2, inset), paint);
    canvas.drawLine(Offset(w - inset, inset), Offset(w - inset, h / 2), paint);
    // Kiri bawah
    canvas.drawLine(Offset(inset, h - inset), Offset(w / 2, h - inset), paint);
    canvas.drawLine(Offset(inset, h - inset), Offset(inset, h / 2), paint);
    // Kanan bawah
    canvas.drawLine(Offset(w - inset, h - inset), Offset(w / 2, h - inset), paint);
    canvas.drawLine(Offset(w - inset, h - inset), Offset(w - inset, h / 2), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.thickness != thickness;
}
