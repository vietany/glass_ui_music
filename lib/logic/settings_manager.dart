import 'package:flutter/material.dart';

class SettingsManager extends ChangeNotifier {
  // Singleton: Để truy cập SettingsManager() từ bất kỳ đâu mà không cần truyền biến
  static final SettingsManager _instance = SettingsManager._internal();
  factory SettingsManager() => _instance;
  SettingsManager._internal();

  // --- CÁC TÙY CHỌN ---

  // false = Dùng bản cũ (Glass), true = Dùng bản mới (Liquid)
  bool useLiquidNav = true;

  void toggleNavStyle(bool value) {
    useLiquidNav = value;
    notifyListeners(); // Báo cho toàn bộ App biết để vẽ lại
  }
}