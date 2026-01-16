import 'package:flutter/material.dart';
import '../utils/nav_config.dart'; // Import Config
import 'glass_card.dart';

class GlassNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const GlassNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 25, left: 20, right: 20),
      borderRadius: 35,
      opacity: 0.1,
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          // Tự động sinh ra các nút dựa trên Config
          children: List.generate(NavConfig.count, (index) {
            // Kiểm tra nếu là nút giữa (Index 2) thì vẽ kiểu khác
            if (index == 2) {
              return _buildCenterItem(index, NavConfig.getIcon(index));
            }
            return _buildNavItem(index, NavConfig.getIcon(index), NavConfig.getLabel(index));
          }),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.cyanAccent : Colors.white38,
            size: 26,
          ),
          const SizedBox(height: 4),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isSelected ? 1.0 : 0.0,
            child: Text(
              label,
              style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterItem(int index, IconData icon) {
    bool isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isSelected ? [Colors.cyanAccent, Colors.blueAccent] : [Colors.white24, Colors.white10],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            boxShadow: [
              if (isSelected) BoxShadow(color: Colors.cyan.withOpacity(0.5), blurRadius: 15, spreadRadius: 1)
            ]
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}