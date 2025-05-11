import 'dart:math';
import 'package:flutter/material.dart';

class WaterBackgroundPainter extends CustomPainter {
  final double waveHeight;
  final double waveSpeed;
  final double waveOffset;

  WaterBackgroundPainter({required this.waveHeight, required this.waveSpeed, required this.waveOffset});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = Colors.blue.shade200.withOpacity(0.5);
    Path path = Path();

    // Start path from the bottom left
    path.lineTo(0, size.height);

    // Create wavy pattern
    for (double i = 0; i < size.width; i++) {
      double y = waveHeight * sin((i + waveOffset) * 0.05) + size.height - 50; // Adjust amplitude
      path.lineTo(i, y);
    }

    // End path at the bottom right
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Redraw the painter each time
  }
}
