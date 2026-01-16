import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class WaterDropOverlay extends StatelessWidget {
  final ui.FragmentProgram? shaderProgram;
  final double centerNormalized;
  final double stretchX;
  final double squashY;
  final double scale;

  const WaterDropOverlay({
    super.key,
    required this.shaderProgram,
    required this.centerNormalized,
    required this.stretchX,
    required this.squashY,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    // FALLBACK: Nếu shader chưa load, vẽ màu đỏ để biết vị trí
    if (shaderProgram == null) {
      return Center(
        child: Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.5),
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(15)
          ),
        ),
      );
    }

    return CustomPaint(
      painter: _GlassPainter(
        shaderProgram: shaderProgram!,
        centerNormalized: centerNormalized,
        stretchX: stretchX,
        squashY: squashY,
        scale: scale,
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  final ui.FragmentProgram shaderProgram;
  final double centerNormalized;
  final double stretchX;
  final double squashY;
  final double scale;

  _GlassPainter({
    required this.shaderProgram,
    required this.centerNormalized,
    required this.stretchX,
    required this.squashY,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Kiểm tra kích thước canvas có hợp lệ không
    if (size.isEmpty) return;

    final shader = shaderProgram.fragmentShader();

    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, centerNormalized);
    shader.setFloat(3, stretchX);
    shader.setFloat(4, squashY);
    shader.setFloat(5, scale);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _GlassPainter oldDelegate) => true;
}