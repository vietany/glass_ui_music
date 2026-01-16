import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class LiquidBackground extends StatefulWidget {
  final Widget child;
  const LiquidBackground({super.key, required this.child});

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground> with SingleTickerProviderStateMixin {
  late AnimationController _blobController;
  late Animation<double> _blobAnimation;

  @override
  void initState() {
    super.initState();
    // Animation chậm rãi, "organic"
    _blobController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _blobAnimation = CurvedAnimation(parent: _blobController, curve: Curves.linear);
  }

  @override
  void dispose() {
    _blobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Nền tối chủ đạo
        Container(color: const Color(0xFF0F0F1E)),

        // 2. Blob Tím mộng mơ (Di chuyển)
        AnimatedBuilder(
          animation: _blobAnimation,
          builder: (context, child) {
            return Positioned(
              top: sin(_blobAnimation.value * 2 * pi) * 50 - 50,
              left: cos(_blobAnimation.value * 2 * pi) * 50 - 20,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Colors.purpleAccent.withOpacity(0.6), Colors.transparent]),
                ),
              ),
            );
          },
        ),

        // 3. Blob Xanh Cyan (Di chuyển ngược lại)
        AnimatedBuilder(
          animation: _blobAnimation,
          builder: (context, child) {
            return Positioned(
              bottom: cos(_blobAnimation.value * 2 * pi) * 50 + 100,
              right: sin(_blobAnimation.value * 2 * pi) * 50 - 50,
              child: Container(
                width: 250, height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Colors.cyanAccent.withOpacity(0.5), Colors.transparent]),
                ),
              ),
            );
          },
        ),

        // 4. Lớp kính mờ toàn màn hình (Làm nhòe các blob)
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(color: Colors.transparent),
        ),

        // 5. Nội dung chính (Sẽ nằm đè lên trên)
        widget.child,
      ],
    );
  }
}