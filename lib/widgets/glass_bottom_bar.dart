import 'package:flutter/material.dart';
import 'glass_card.dart'; // Import GlassContainer & GlassIconButton
import 'pulsing_mic_button.dart'; // Import nút Mic vừa tạo

class GlassBottomBar extends StatelessWidget {
  final bool isRecording;
  final bool isPlaying;
  final VoidCallback onRecordTap;
  final VoidCallback onPlayTap;
  final VoidCallback onClearTap;

  const GlassBottomBar({
    super.key,
    required this.isRecording,
    required this.isPlaying,
    required this.onRecordTap,
    required this.onPlayTap,
    required this.onClearTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      borderRadius: 30,
      opacity: 0.15, // Kính đậm hơn chút cho dễ nhìn
      child: SizedBox(
        height: 90,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 1. Nút Xóa (Bên trái)
            GlassIconButton(
              icon: Icons.delete_outline_rounded,
              label: "Clear",
              onTap: onClearTap,
            ),

            // 2. Nút Mic (Chính giữa - Có hiệu ứng Pulse)
            PulsingMicButton(
              isRecording: isRecording,
              onTap: onRecordTap,
            ),

            // 3. Nút Play (Bên phải)
            GlassIconButton(
              icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              label: isPlaying ? "Pause" : "Play",
              onTap: onPlayTap,
            ),
          ],
        ),
      ),
    );
  }
}