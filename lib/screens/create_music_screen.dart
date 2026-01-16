import 'dart:math';
import 'package:flutter/material.dart';

// Import Logic và Widgets
import '../logic/music_session_manager.dart';
import '../logic/settings_manager.dart'; // Import Settings Manager
import '../utils/painters.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_bottom_bar.dart';
import '../widgets/analyzer_view.dart';

class CreateMusicScreen extends StatefulWidget {
  const CreateMusicScreen({super.key});
  @override
  State<CreateMusicScreen> createState() => _CreateMusicScreenState();
}

class _CreateMusicScreenState extends State<CreateMusicScreen> {
  // Khai báo Manager
  final MusicSessionManager _manager = MusicSessionManager();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _manager.init();

    // Lắng nghe yêu cầu cuộn từ Logic
    _manager.onScrollRequest = (targetX) {
      if (_scrollController.hasClients) {
        // Chỉ cuộn nếu vị trí vượt quá nửa màn hình
        if (targetX > MediaQuery.of(context).size.width / 2) {
          _scrollController.animateTo(
              targetX - MediaQuery.of(context).size.width / 2,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut
          );
        }
      }
    };
  }

  @override
  void dispose() {
    _manager.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder: Tự động rebuild khi Manager gọi notifyListeners()
    return ListenableBuilder(
      listenable: _manager,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                // 1. Header (Có nút Settings)
                _buildHeader(),

                // 2. Sheet Nhạc
                Expanded(
                  flex: 3,
                  child: GlassContainer(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    hasGlow: true,
                    child: Column(
                      children: [
                        _buildStatusStep(),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(right: 200, left: 20),
                            child: SizedBox(
                              width: max(MediaQuery.of(context).size.width, _manager.notes.length * 60.0 + 200),
                              child: CustomPaint(
                                  painter: StaffPainter(
                                      _manager.notes,
                                      _manager.currentPlaybackPosition,
                                      isPlaying: _manager.isPlaying
                                  ),
                                  size: Size.infinite
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Biểu đồ sóng
                AnalyzerView(pitchHistory: _manager.pitchHistory),

                const SizedBox(height: 30),

                // 4. Thanh điều khiển (Play/Rec)
                GlassBottomBar(
                  isRecording: _manager.isRecording,
                  isPlaying: _manager.isPlaying,
                  onClearTap: _manager.clear,
                  onRecordTap: _manager.isRecording ? _manager.stopRecording : _manager.startRecording,
                  onPlayTap: _manager.togglePlayback,
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("AI Composer", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),

          Row(
            children: [
              // Nút Cài đặt
              _buildSettingsButton(),
              const SizedBox(width: 10),
              // Nút Chọn Ngôn ngữ
              _buildLanguageDropdown(),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSettingsButton() {
    return Container(
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
      child: IconButton(
        icon: const Icon(Icons.settings_rounded, color: Colors.white54, size: 20),
        onPressed: _showSettingsDialog,
      ),
    );
  }

  Widget _buildLanguageDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
            value: 'vi_VN',
            dropdownColor: const Color(0xFF0F0F1E),
            icon: const Icon(Icons.language, color: Colors.white54, size: 16),
            items: const [
              DropdownMenuItem(value: 'vi_VN', child: Text("VIE", style: TextStyle(color: Colors.white, fontSize: 12))),
              DropdownMenuItem(value: 'en_US', child: Text("ENG", style: TextStyle(color: Colors.white, fontSize: 12))),
            ],
            onChanged: (v) => _manager.setLocale(v!)
        ),
      ),
    );
  }

  Widget _buildStatusStep() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      width: double.infinity,
      color: Colors.white.withOpacity(0.05),
      child: Center(
          child: Text(
            _manager.isRecording ? "Listening: ${_manager.lastWords}" : "Ready to compose",
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
      ),
    );
  }

  // --- SETTINGS DIALOG ---
  void _showSettingsDialog() {
    final settings = SettingsManager(); // Singleton
    showDialog(
      context: context,
      builder: (ctx) => ListenableBuilder(
          listenable: settings,
          builder: (context, child) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2E).withOpacity(0.95), // Màu tối kính
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Settings", style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text("Liquid Navigation", style: TextStyle(color: Colors.white70)),
                    subtitle: const Text("Fluid animation effect", style: TextStyle(color: Colors.white30, fontSize: 12)),
                    value: settings.useLiquidNav,
                    activeColor: Colors.cyanAccent,
                    inactiveTrackColor: Colors.white10,
                    onChanged: (val) {
                      settings.toggleNavStyle(val);
                    },
                  ),
                  // Có thể thêm Sensitivity slider ở đây sau này
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Close", style: TextStyle(color: Colors.cyanAccent)),
                )
              ],
            );
          }
      ),
    );
  }
}