import 'dart:ui';
import 'package:flutter/material.dart';
import 'screens/create_music_screen.dart';

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
        scaffoldBackgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Colors.blueAccent,
          thumbColor: Colors.white,
        )
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
  int _idx = 2;
  final List<Widget> _pages = [
    const Center(child: Text("Home")),
    const Center(child: Text("Explore")),
    const CreateMusicScreen(),
    const Center(child: Text("Chat")),
    const Center(child: Text("Profile")),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: IndexedStack(index: _idx, children: _pages),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        backgroundColor: Colors.black,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
           BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
           BottomNavigationBarItem(icon: Icon(Icons.explore), label: "Explore"),
           BottomNavigationBarItem(icon: Icon(Icons.mic), label: "Create"),
           BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chat"),
           BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
