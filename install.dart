import 'dart:io';

void main() async {
  // 1. Định nghĩa cấu trúc và nội dung file
  final Map<String, String> projectFiles = {
    'lib/utils/wav_header.dart': r'''
import 'dart:io';
import 'dart:typed_data';

Future<void> addWavHeader(String path) async {
  File file = File(path);
  if (!await file.exists()) return;

  var bytes = await file.readAsBytes();
  int totalDataLen = bytes.length;
  int longSampleRate = 44100;
  int channels = 1;
  int byteRate = 44100 * 2;

  var header = Uint8List(44);
  var view = ByteData.view(header.buffer);

  _writeString(view, 0, 'RIFF');
  view.setUint32(4, 36 + totalDataLen, Endian.little);
  _writeString(view, 8, 'WAVE');
  _writeString(view, 12, 'fmt ');
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, channels, Endian.little);
  view.setUint32(24, longSampleRate, Endian.little);
  view.setUint32(28, byteRate, Endian.little);
  view.setUint16(32, 2, Endian.little);
  view.setUint16(34, 16, Endian.little);
  _writeString(view, 36, 'data');
  view.setUint32(40, totalDataLen, Endian.little);

  var newBytes = BytesBuilder();
  newBytes.add(header);
  newBytes.add(bytes);
  await file.writeAsBytes(newBytes.toBytes());
}

void _writeString(ByteData view, int offset, String value) {
  for (int i = 0; i < value.length; i++) {
    view.setUint8(offset + i, value.codeUnitAt(i));
  }
}
''',
    'lib/utils/audio_analyzer.dart': r'''
import 'dart:typed_data';

enum NoteType { whole, half, quarter, eighth, sixteenth }

class MusicNote {
  final String name;
  final int position;
  final NoteType type;
  final String lyric;
  MusicNote(this.name, this.position, this.type, this.lyric);
}

class AudioAnalyzer {
  static Map<String, dynamic> analyzeChunk(Uint8List chunk, int threshold) {
    int zeroCrossings = 0;
    int lastSign = 0;
    int sum = 0;

    for (int i = 0; i < chunk.length; i += 2) {
      if (i + 1 < chunk.length) {
        int val = chunk[i] | (chunk[i + 1] << 8);
        if (val > 32767) val -= 65536;
        
        sum += val.abs();
        int sign = val >= 0 ? 1 : -1;
        if (lastSign != 0 && sign != lastSign) zeroCrossings++;
        lastSign = sign;
      }
    }

    double volume = (sum / (chunk.length / 2)) / 10000.0;
    volume = volume.clamp(0.0, 1.0);

    MusicNote? note;
    int realThreshold = 100 + (threshold * 50); 
    
    if (sum > realThreshold * (chunk.length / 50)) {
       int rawPitch = zeroCrossings % 7;
       String name = _getNoteName(rawPitch);
       note = MusicNote(name, rawPitch, NoteType.quarter, "");
    }

    return {
      "volume": volume,
      "note": note
    };
  }

  static String _getNoteName(int index) {
    switch (index) {
      case 0: return "C"; case 1: return "D"; case 2: return "E";
      case 3: return "F"; case 4: return "G"; case 5: return "A";
      case 6: return "B"; default: return "C";
    }
  }
}
''',
    'lib/utils/painters.dart': r'''
import 'package:flutter/material.dart';
import 'audio_analyzer.dart';

class StaffPainter extends CustomPainter {
  final List<MusicNote> notes;
  StaffPainter(this.notes);

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()..color = Colors.black87..strokeWidth = 1.5;
    final paintNote = Paint()..color = Colors.black..style = PaintingStyle.fill;
    final paintStem = Paint()..color = Colors.black..strokeWidth = 2;
    
    double startY = size.height / 2 - 40;
    double lineSpacing = 15.0;

    for (int i = 0; i < 5; i++) {
      double y = startY + (i * lineSpacing);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintLine);
    }
    
    const TextSpan(text: "𝄞", style: TextStyle(color: Colors.black, fontSize: 60))
        .toPainter()..layout()..paint(canvas, Offset(10, startY - 25));

    double currentX = 80.0;
    for (var note in notes) {
      double noteY = startY + (4 * lineSpacing);
      if (note.name == "C") noteY += lineSpacing;
      else if (note.name == "D") noteY += 0.5 * lineSpacing;
      else if (note.name == "E") noteY += 0;
      else if (note.name == "F") noteY -= 0.5 * lineSpacing;
      else if (note.name == "G") noteY -= 1 * lineSpacing;
      else if (note.name == "A") noteY -= 1.5 * lineSpacing;
      else if (note.name == "B") noteY -= 2 * lineSpacing;

      canvas.drawOval(Rect.fromCenter(center: Offset(currentX, noteY), width: 14, height: 10), paintNote);
      canvas.drawLine(Offset(currentX + 6, noteY), Offset(currentX + 6, noteY - 35), paintStem);
      
      if (note.name == "C") canvas.drawLine(Offset(currentX - 12, noteY), Offset(currentX + 12, noteY), paintLine);
      
      TextPainter(text: TextSpan(text: note.lyric, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)
        ..layout()..paint(canvas, Offset(currentX - 10, startY + 5 * lineSpacing + 5));

      currentX += 50.0;
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
extension TextSpanExt on TextSpan { TextPainter toPainter() => TextPainter(text: this, textDirection: TextDirection.ltr); }
''',
    'lib/widgets/glass_card.dart': r'''
import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(20)),
          child: child
        )
      )
    );
  }
}
class GlassActionButton extends StatelessWidget {
  final IconData icon; final String label;
  const GlassActionButton({super.key, required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1), border: Border.all(color: Colors.white24)), child: Icon(icon, color: Colors.white)),
      const SizedBox(height: 8), Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70))
    ]);
  }
}
''',
    'lib/screens/create_music_screen.dart': r'''
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
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

  Future<void> _startRecording() async {
    await _audioPlayer.stop();
    setState(() { _isRecording = true; _realtimeNotes.clear(); _currentVolume = 0.0; });

    if (await _audioRecorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      _recordedFilePath = '${dir.path}/temp_song.wav';
      
      File file = File(_recordedFilePath!);
      _fileSink = file.openWrite();

      final stream = await _audioRecorder.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bit, sampleRate: 44100, numChannels: 1));

      _audioStreamSub = stream.listen((chunk) {
        _fileSink?.add(chunk);
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
    }
  }

  Future<void> _stopRecording() async {
    await _audioRecorder.stop();
    await _audioStreamSub?.cancel();
    await _fileSink?.close();
    
    if (_recordedFilePath != null) {
      await addWavHeader(_recordedFilePath!);
    }

    setState(() { _isRecording = false; _currentVolume = 0.0; });
  }

  Future<void> _playRecording() async {
    if (_recordedFilePath != null && File(_recordedFilePath!).existsSync()) {
      await _audioPlayer.play(DeviceFileSource(_recordedFilePath!));
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
''',
    'lib/main.dart': r'''
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
'''
  };

  // 2. Thực hiện tạo file
  for (var entry in projectFiles.entries) {
    final path = entry.key;
    final content = entry.value;
    
    final file = File(path);
    // Tạo thư mục nếu chưa có
    await file.parent.create(recursive: true);
    
    // Ghi nội dung
    await file.writeAsString(content);
    print('✅ Đã tạo: $path');
  }

  print('\n🎉 HOÀN TẤT! Cấu trúc dự án đã được tạo tự động.');
  print('👉 Hãy bấm RUN (Tam giác xanh) để chạy App.');
}