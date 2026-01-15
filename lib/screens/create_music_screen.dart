import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui'; // Cần import thư viện này cho ImageFilter
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../utils/audio_analyzer.dart';
import '../utils/painters.dart';
import '../utils/wav_header.dart';
import '../widgets/glass_card.dart';

class CreateMusicScreen extends StatefulWidget {
  const CreateMusicScreen({super.key});
  @override
  State<CreateMusicScreen> createState() => _CreateMusicScreenState();
}

class _CreateMusicScreenState extends State<CreateMusicScreen> with TickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollController = ScrollController();

  // Animation cho Liquid Background
  late AnimationController _blobController;
  late Animation<double> _blobAnimation;

  // Animation nút ghi âm
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isRecording = false;
  double _currentVolume = 0.0;

  List<MusicNote> _realtimeNotes = [];
  List<double> _pitchHistory = [];

  StreamSubscription<Uint8List>? _audioStreamSub;
  IOSink? _fileSink;
  String? _recordedFilePath;

  double _micSensitivity = 50.0;

  // Lời bài hát
  final List<String> _lyrics = ["Đồ", "Rê", "Mi", "Fa", "Son", "La", "Si", "Đố", "Yêu", "Đời"];
  int _lyricIdx = 0;

  // Biến kiểm soát thời gian để ghi nốt (Throttle)
  DateTime _lastNoteTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // 1. Setup Animation "Liquid" (Chuyển động chậm, organic)
    _blobController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _blobAnimation = CurvedAnimation(parent: _blobController, curve: Curves.linear);

    // 2. Setup Animation nút Mic
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _blobController.dispose();
    _pulseController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (await Permission.microphone.request() != PermissionStatus.granted) return;

    await _audioPlayer.stop();
    setState(() {
      _isRecording = true;
      _realtimeNotes.clear();
      _pitchHistory.clear();
      _currentVolume = 0.0;
      _lyricIdx = 0;
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      _recordedFilePath = '${dir.path}/song_session.wav';

      File file = File(_recordedFilePath!);
      if (file.existsSync()) await file.delete();
      _fileSink = file.openWrite();

      // Dùng PCM 16bit để Analyzer hoạt động chuẩn
      final stream = await _audioRecorder.startStream(
          const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 44100, numChannels: 1)
      );

      _audioStreamSub = stream.listen((chunk) {
        _fileSink?.add(chunk);

        var result = AudioAnalyzer.analyzeChunk(chunk, _micSensitivity.toInt());

        setState(() {
          _currentVolume = result['volume'];
          double pitch = result['pitch'];

          if (_pitchHistory.length > 100) _pitchHistory.removeAt(0);
          _pitchHistory.add(pitch);

          MusicNote? note = result['note'];

          // --- LOGIC MỚI: DỄ TÍNH HƠN ---
          // Chỉ cần:
          // 1. Có nốt nhạc được phát hiện (Pitch hợp lệ)
          // 2. Âm lượng đủ lớn (tránh tiếng quạt, tiếng gió)
          // 3. Đã qua khoảng thời gian chờ (Throttle) - ví dụ 300ms ghi 1 nốt

          bool isLoudEnough = _currentVolume > 0.1; // Ngưỡng âm lượng (0.0 -> 1.0)
          bool timePassed = DateTime.now().difference(_lastNoteTime).inMilliseconds > 400; // Tốc độ ghi nốt

          if (note != null && isLoudEnough && timePassed) {
            String currentLyric = _lyrics[_lyricIdx % _lyrics.length];

            // Thêm nốt vào danh sách
            _realtimeNotes.add(MusicNote(
                note.name,
                note.position,
                NoteType.quarter,
                currentLyric
            ));

            _lyricIdx++; // Chuyển sang từ tiếp theo
            _lastNoteTime = DateTime.now(); // Reset bộ đếm thời gian

            // Tự động cuộn sheet nhạc
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent + 60, // Cuộn thêm 1 chút
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut
              );
            }
          }
        });
      });
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> _stopRecording() async {
    await _audioRecorder.stop();
    await _audioStreamSub?.cancel();
    await _fileSink?.close();

    if (_recordedFilePath != null) await addWavHeader(_recordedFilePath!);

    setState(() { _isRecording = false; _currentVolume = 0.0; });
  }

  Future<void> _playRecording() async {
    if (_recordedFilePath != null) {
      await _audioPlayer.play(DeviceFileSource(_recordedFilePath!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // --- 1. LIQUID BACKGROUND (Hiệu ứng iOS 26) ---
        // Nền tối
        Container(color: const Color(0xFF0F0F1E)),

        // Blob 1: Tím mộng mơ (Di chuyển)
        AnimatedBuilder(
          animation: _blobAnimation,
          builder: (context, child) {
            return Positioned(
              top: sin(_blobAnimation.value * 2 * pi) * 50 - 50,
              left: cos(_blobAnimation.value * 2 * pi) * 50 - 20,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Colors.purpleAccent.withOpacity(0.6), Colors.transparent]),
                ),
              ),
            );
          },
        ),

        // Blob 2: Xanh Cyan (Di chuyển ngược lại)
        AnimatedBuilder(
          animation: _blobAnimation,
          builder: (context, child) {
            return Positioned(
              bottom: cos(_blobAnimation.value * 2 * pi) * 50 + 100,
              right: sin(_blobAnimation.value * 2 * pi) * 50 - 50,
              child: Container(
                width: 250, height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Colors.cyanAccent.withOpacity(0.5), Colors.transparent]),
                ),
              ),
            );
          },
        ),

        // Lớp phủ mờ toàn màn hình (Tạo hiệu ứng kính lỏng cho nền)
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(color: Colors.transparent),
        ),

        // --- 2. NỘI DUNG CHÍNH ---
        SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("AI Composer", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
                      child: Text(_isRecording ? "● REC" : "READY", style: TextStyle(color: _isRecording ? Colors.redAccent : Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),

              // --- KHU VỰC SHEET NHẠC (GLASS CARD) ---
              Expanded(
                flex: 3,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)]
                        ),
                        child: Column(
                          children: [
                            // Thanh tiêu đề nhỏ của sheet
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              width: double.infinity,
                              color: Colors.white.withOpacity(0.05),
                              child: const Center(child: Text("Live Transcription", style: TextStyle(color: Colors.white54, fontSize: 12))),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(right: 200, left: 20),
                                child: SizedBox(
                                  width: max(MediaQuery.of(context).size.width, _realtimeNotes.length * 70.0 + 200),
                                  child: CustomPaint(
                                      painter: StaffPainter(_realtimeNotes), // Vẽ nốt nhạc + Lời
                                      size: Size.infinite
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --- ANALYZER (VISUALIZER) ---
              Container(
                height: 100,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10)
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CustomPaint(
                    painter: PitchGraphPainter(_pitchHistory),
                    size: Size.infinite,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // --- 3. THANH NAVI (LIQUID GLASS BOTTOM BAR) ---
              Container(
                height: 100,
                margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // Kính mờ cực mạnh
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1), // Trong suốt
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withOpacity(0.3)), // Viền sáng
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: -5)]
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildGlassIcon(Icons.settings, "Config"),

                          // Nút Record chính giữa
                          GestureDetector(
                            onTap: _isRecording ? _stopRecording : _startRecording,
                            child: AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) => Transform.scale(
                                scale: _isRecording ? _pulseAnimation.value : 1.0,
                                child: Container(
                                  width: 70, height: 70,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                                          colors: _isRecording
                                              ? [Colors.redAccent, Colors.pinkAccent]
                                              : [Colors.white, Colors.white70]
                                      ),
                                      boxShadow: [
                                        BoxShadow(color: _isRecording ? Colors.redAccent.withOpacity(0.5) : Colors.white.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)
                                      ]
                                  ),
                                  child: Icon(_isRecording ? Icons.stop : Icons.mic, color: _isRecording ? Colors.white : Colors.black87, size: 32),
                                ),
                              ),
                            ),
                          ),

                          _buildGlassIcon(Icons.play_arrow_rounded, "Play", onTap: _playRecording),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlassIcon(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
            child: Icon(icon, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10))
        ],
      ),
    );
  }
}

// --- PAINTERS (Analyzer Graph) ---
class PitchGraphPainter extends CustomPainter {
  final List<double> pitches;
  PitchGraphPainter(this.pitches);

  @override
  void paint(Canvas canvas, Size size) {
    // Vẽ đường line neon
    Paint linePaint = Paint()
      ..shader = const LinearGradient(colors: [Colors.cyanAccent, Colors.purpleAccent]).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Hiệu ứng Glow cho đường line
    Paint glowPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.4)
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..style = PaintingStyle.stroke;

    if (pitches.isEmpty) return;

    Path path = Path();
    double minFreq = 100;
    double maxFreq = 800;
    double stepX = size.width / 100;

    for (int i = 0; i < pitches.length; i++) {
      double freq = pitches[i];
      double x = i * stepX;

      // Nếu không có âm thanh (freq=0), vẽ ở giữa hoặc đáy
      double y = size.height;
      if (freq > 0) {
        double normalizedY = 1.0 - ((freq - minFreq) / (maxFreq - minFreq)).clamp(0.0, 1.0);
        y = normalizedY * size.height;
      }

      if (i == 0) path.moveTo(x, y); else {
        // Làm mịn đường cong (Bezier)
        double prevX = (i - 1) * stepX;
        path.quadraticBezierTo(prevX, y, x, y);
      }
    }
    canvas.drawPath(path, glowPaint); // Vẽ bóng trước
    canvas.drawPath(path, linePaint); // Vẽ nét chính
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}