import 'package:flutter/material.dart';

class PulsingMicButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onTap;

  const PulsingMicButton({
    super.key,
    required this.isRecording,
    required this.onTap,
  });

  @override
  State<PulsingMicButton> createState() => _PulsingMicButtonState();
}

class _PulsingMicButtonState extends State<PulsingMicButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Tạo nhịp thở (Pulse) 1.5 giây
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true); // Lặp lại liên tục

    _animation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Chỉ scale (phóng to) khi đang ghi âm
          return Transform.scale(
            scale: widget.isRecording ? _animation.value : 1.0,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Đổi màu gradient khi ghi âm
                gradient: LinearGradient(
                  colors: widget.isRecording
                      ? [Colors.redAccent, Colors.pink]
                      : [Colors.white, Colors.white70],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isRecording
                        ? Colors.red.withOpacity(0.5)
                        : Colors.white24,
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Icon(
                widget.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: widget.isRecording ? Colors.white : Colors.black87,
                size: 32,
              ),
            ),
          );
        },
      ),
    );
  }
}