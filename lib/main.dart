import 'package:flutter/material.dart';
import 'logic/settings_manager.dart'; // Import Settings
import 'screens/create_music_screen.dart';
import 'widgets/liquid_background.dart';
import 'widgets/liquid_nav_bar.dart';
import 'widgets/glass_navigation_bar.dart'; // Import bản cũ
import 'widgets/glass_showroom.dart'; // <--- THÊM IMPORT NÀY
import 'widgets/glass_lab.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F1E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final PageController _pageController = PageController(initialPage: 2);
  final SettingsManager _settings = SettingsManager(); // Gọi Singleton
  int _idx = 2;

  final List<Widget> _pages = [
    // --- THAY THẾ TAB HOME BẰNG SHOWROOM ---
    const GlassLab(),

    const Center(child: Text("Explore", style: TextStyle(color: Colors.white54, fontSize: 20))),
    const CreateMusicScreen(),
    const Center(child: Text("Chat", style: TextStyle(color: Colors.white54, fontSize: 20))),
    const Center(child: Text("Profile", style: TextStyle(color: Colors.white54, fontSize: 20))),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    setState(() => _idx = index);
    _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeOutQuad);
  }

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder: Tự động vẽ lại màn hình khi Settings thay đổi
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, child) {
        return LiquidBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _idx = i),
              physics: const BouncingScrollPhysics(),
              children: _pages,
            ),

            // --- LOGIC CHUYỂN ĐỔI NAVI ---
            bottomNavigationBar: _settings.useLiquidNav
                ? LiquidNavBar(currentIndex: _idx, onTap: _onNavTap)
                : GlassNavigationBar(currentIndex: _idx, onTap: _onNavTap),
          ),
        );
      },
    );
  }
}