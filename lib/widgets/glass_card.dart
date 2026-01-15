import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(20)),
          child: child
        )
      )
    );
  }
}
class GlassActionButton extends StatelessWidget {
  final IconData icon; final String label;
  const GlassActionButton({super.key, required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1), border: Border.all(color: Colors.white24)), child: Icon(icon, color: Colors.white)),
      const SizedBox(height: 8), Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70))
    ]);
  }
}
