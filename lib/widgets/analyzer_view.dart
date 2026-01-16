import 'package:flutter/material.dart';
import '../utils/painters.dart'; // Import PitchGraphPainter từ đây
import 'glass_card.dart';

class AnalyzerView extends StatelessWidget {
  final List<double> pitchHistory;

  const AnalyzerView({super.key, required this.pitchHistory});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.zero,
      borderRadius: 16,
      child: SizedBox(
        height: 100,
        width: double.infinity,
        child: CustomPaint(
          painter: PitchGraphPainter(pitchHistory),
          size: Size.infinite,
        ),
      ),
    );
  }
}