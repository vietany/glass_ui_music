import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Painter vẽ miếng kính (Glass Overlay)
class FlatGlassPainter extends CustomPainter {
  final ui.FragmentProgram shaderProgram;
  final int variantIndex;
  final double time;
  final Offset itemPosition; // Tọa độ toàn cục để tính khúc xạ
  final Size screenSize;
  final double stretchX;     // Biến dạng dãn
  final double squashY;      // Biến dạng nén

  FlatGlassPainter({
    required this.shaderProgram,
    required this.variantIndex,
    required this.time,
    required this.itemPosition,
    required this.screenSize,
    required this.stretchX,
    required this.squashY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = shaderProgram.fragmentShader();

    // Set uniforms
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, variantIndex.toDouble());
    shader.setFloat(4, screenSize.width);
    shader.setFloat(5, screenSize.height);
    shader.setFloat(6, itemPosition.dx);
    shader.setFloat(7, itemPosition.dy);
    shader.setFloat(8, stretchX);
    shader.setFloat(9, squashY);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant FlatGlassPainter oldDelegate) {
    return oldDelegate.itemPosition != itemPosition ||
        oldDelegate.time != time ||
        oldDelegate.stretchX != stretchX;
  }
}

/// Painter vẽ nền (Background)
class BackgroundDummyPainter extends CustomPainter {
  final ui.FragmentProgram shaderProgram;
  final double time;
  final Size screenSize;

  BackgroundDummyPainter(this.shaderProgram, this.time, this.screenSize);

  @override
  void paint(Canvas canvas, Size size) {
    final shader = shaderProgram.fragmentShader();
    // Variant -1.0 báo hiệu cho Shader vẽ background
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, -1.0);
    shader.setFloat(4, screenSize.width);
    shader.setFloat(5, screenSize.height);
    // Các tham số còn lại không quan trọng với BG
    shader.setFloat(6, 0.0);
    shader.setFloat(7, 0.0);
    shader.setFloat(8, 1.0);
    shader.setFloat(9, 1.0);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant BackgroundDummyPainter oldDelegate) => true;
}