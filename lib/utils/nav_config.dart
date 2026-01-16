import 'package:flutter/material.dart';

class NavItem {
  final IconData icon;
  final String label;

  const NavItem({required this.icon, required this.label});
}

class NavConfig {
  // Danh sách Tab duy nhất của ứng dụng
  static const List<NavItem> items = [
    NavItem(icon: Icons.home_rounded, label: "Home"),       // Index 0
    NavItem(icon: Icons.explore_rounded, label: "Explore"), // Index 1
    NavItem(icon: Icons.mic_rounded, label: "Create"),      // Index 2 (Nút giữa)
    NavItem(icon: Icons.chat_bubble_rounded, label: "Chat"),// Index 3
    NavItem(icon: Icons.person_rounded, label: "Profile"),  // Index 4
  ];

  // Hàm tiện ích để lấy Icon
  static IconData getIcon(int index) => items[index].icon;

  // Hàm tiện ích để lấy Label
  static String getLabel(int index) => items[index].label;

  // Lấy tổng số tab
  static int get count => items.length;
}