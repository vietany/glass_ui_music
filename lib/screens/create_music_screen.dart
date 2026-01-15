import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart'; // Đã thêm thư viện này
import 'package:record/record.dart';

// Giữ nguyên các import utility của bạn
import '../utils/audio_analyzer.dart';
import '../utils/painters.dart';
import '../utils/wav_header.dart';
import '../widgets/glass_card.dart';

class CreateMusicScreen extends StatefulWidget {
  const CreateMusicScreen({super.key});
  @override
  State<CreateMusicScreen> createState() => _CreateMusicScreenState();
}

class _CreateMusicScreenState extends State<CreateMusicScreen> with SingleTickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isRecording = false;
  double _currentVolume = 0.0;
  List<MusicNote> _realtimeNotes = [];

  StreamSubscription<Uint8List>? _audioStreamSub;
  IOSink? _fileSink;
  String? _recordedFilePath;

  double _micSensitivity = 50.0;

  final List<String> _lyrics = ["Đồ", "Rê", "Mi", "Fa", "Sol", "La", "Si", "Đố"];
  int _lyricIdx = 0;
  String? _lastNoteName;
  int _holdCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
            builder: (context, setModalState) {
              return GlassCard(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  height: 250,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Cài đặt Âm thanh", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Độ nhạy Micro:", style: TextStyle(color: Colors.white70)),
                          Text("${_micSensitivity.toInt()}%", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Slider(
                        value: _micSensitivity,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: "${_micSensitivity.toInt()}%",
                        onChanged: (value) {
                          setModalState(() => _micSensitivity = value);
                          setState(() => _micSensitivity = value);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }
        );
      },
    );
  }

  // --- HÀM ĐÃ SỬA CHỮA ---
  Future<void> _startRecording() async {
    // 1. Xin quyền Microphone trước
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vui lòng cấp quyền Microphone để ghi âm!")),
        );
      }
      return;
    }

    await _audioPlayer.stop();
    setState(() { _isRecording = true; _realtimeNotes.clear(); _currentVolume = 0.0; });

    try {
      final dir = await getApplicationDocumentsDirectory();
      _recordedFilePath = '${dir.path}/temp_song.wav';

      File file = File(_recordedFilePath!);
      _fileSink = file.openWrite();

      // 2. Sửa encoder thành wav
      final stream = await _audioRecorder.startStream(
          const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 44100, numChannels: 1)
      );

      _audioStreamSub = stream.listen((chunk) {
        _fileSink?.add(chunk);

        // Phân tích âm thanh
        var result = AudioAnalyzer.analyzeChunk(chunk, _micSensitivity.toInt());

        setState(() {
          _currentVolume = result['volume'];

          MusicNote? note = result['note'];
          if (note != null) {
            if (note.name == _lastNoteName) {
              _holdCount++;
            } else {
              _holdCount = 0;
              _lastNoteName = note.name;
            }

            if (_holdCount > 2 && _holdCount % 4 == 0) {
              _realtimeNotes.add(MusicNote(note.name, note.position, NoteType.quarter, _lyrics[_lyricIdx % _lyrics.length]));
              _lyricIdx++;
              if (_scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
            }
          }
        });
      });
    } catch (e) {
      print("Lỗi khi bắt đầu ghi âm: $e");
      setState(() => _isRecording = false);
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      await _audioStreamSub?.cancel();
      await _fileSink?.close();

      // Quan trọng: Thêm header WAV để file có thể phát được
      if (_recordedFilePath != null) {
        await addWavHeader(_recordedFilePath!);
      }
    } catch (e) {
      print("Lỗi khi dừng ghi âm: $e");
    }

    setState(() { _isRecording = false; _currentVolume = 0.0; });
  }

  Future<void> _playRecording() async {
    if (_recordedFilePath != null && File(_recordedFilePath!).existsSync()) {
      try {
        await _audioPlayer.play(DeviceFileSource(_recordedFilePath!));
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi phát file: $e")));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chưa có file nào!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const Text("AI Composer Pro", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              // Mic Level Visualizer
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(5)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _currentVolume.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                        color: _currentVolume > 0.8 ? Colors.red : Colors.greenAccent,
                        borderRadius: BorderRadius.circular(5)
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(_isRecording ? "Mic Level: ${(_currentVolume * 100).toInt()}%" : "Mic Standby", style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ),

        Expanded(
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(10)),
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 100),
              child: SizedBox(
                width: max(MediaQuery.of(context).size.width, _realtimeNotes.length * 50.0 + 200),
                child: CustomPaint(painter: StaffPainter(_realtimeNotes), size: Size.infinite),
              ),
            ),
          ),
        ),

        SizedBox(
          height: 150,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                  onTap: _showSettingsDialog,
                  child: const GlassActionButton(icon: Icons.settings, label: "Độ nhạy")
              ),

              GestureDetector(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isRecording ? _pulseAnimation.value : 1.0,
                      child: Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: _isRecording ? Colors.redAccent : Colors.white),
                        child: Icon(_isRecording ? Icons.stop : Icons.mic, size: 35, color: _isRecording ? Colors.white : Colors.black),
                      ),
                    );
                  },
                ),
              ),

              GestureDetector(onTap: _playRecording, child: const GlassActionButton(icon: Icons.play_arrow, label: "Phát lại")),
            ],
          ),
        ),
      ],
    );
  }
}