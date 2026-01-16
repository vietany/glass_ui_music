import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../utils/nav_config.dart';

class GlassLab extends StatefulWidget {
  const GlassLab({super.key});

  @override
  State<GlassLab> createState() => _GlassLabState();
}

class _GlassLabState extends State<GlassLab> with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _shaderProgram;
  late Ticker _ticker;
  double _time = 0.0;
  final GlobalKey _navKey = GlobalKey();

  // --- CÁC THÔNG SỐ KÍNH (STATE) ---
  double _refraction = 0.04; // Khúc xạ (Độ méo)
  double _specular = 80.0;   // Độ bóng (Càng cao bóng càng gọn)
  double _opacity = 0.08;    // Độ đậm
  double _frost = 0.0;       // Độ mờ đục
  double _chroma = 0.5;      // Tán sắc

  // State vị trí & Vật lý
  double _dragNorm = 0.5;
  double _visualNorm = 0.5;
  int _activeIndex = 2;
  double _stretchX = 1.0;
  double _squashY = 1.0;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _ticker = createTicker((elapsed) {
      if (!mounted) return;
      setState(() {
        _time = elapsed.inMilliseconds / 1000.0;
      });
    });
    _ticker.start();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/flat_glass_collection.frag');
      setState(() => _shaderProgram = program);
    } catch (e) {
      debugPrint("Shader Error: $e");
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // Logic Nam châm
  double _applyMagnet(double raw) {
    double scaled = raw * 3.0;
    double anchor = scaled.roundToDouble();
    double dist = scaled - anchor;
    double pull = -(dist - (dist*dist*dist)/6) * 0.15; // Sin approx
    return (scaled + pull) / 3.0;
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    if (_shaderProgram == null) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // 1. NỀN CARO (Vẽ toàn màn hình)
          Positioned.fill(
            child: CustomPaint(
              painter: _LabBackgroundPainter(_shaderProgram!, _time, screenSize),
            ),
          ),

          Column(
            children: [
              // --- PHẦN PREVIEW (THANH NAVI) ---
              Expanded(
                flex: 4,
                child: Center(
                  child: _buildPreviewNav(screenSize),
                ),
              ),

              // --- PHẦN BẢNG ĐIỀU KHIỂN ---
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, -10))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "THÔNG SỐ KÍNH (LABORATORY)",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 20),

                      Expanded(
                        child: ListView(
                          children: [
                            _buildSlider("Khúc xạ (Refraction)", _refraction, 0.0, 0.1, (v) => _refraction = v),
                            _buildSlider("Độ bóng (Specular)", _specular, 10.0, 300.0, (v) => _specular = v),
                            _buildSlider("Độ đậm (Opacity)", _opacity, 0.0, 1.0, (v) => _opacity = v),
                            _buildSlider("Độ mờ đục (Frost)", _frost, 0.0, 1.0, (v) => _frost = v),
                            _buildSlider("Tán sắc (Chroma)", _chroma, 0.0, 5.0, (v) => _chroma = v),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewNav(Size screenSize) {
    const double navHeight = 80; // To hơn chút để dễ nhìn

    return Container(
      key: _navKey,
      width: screenSize.width * 0.9,
      height: navHeight,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double totalW = constraints.maxWidth;
          double glassW = totalW / 4;
          double maxOffset = totalW - glassW;
          double currentLeft = _visualNorm * maxOffset;

          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Icons
              Row(
                children: List.generate(4, (i) {
                  bool active = _activeIndex == i;
                  return Expanded(
                    child: Icon(
                      NavConfig.getIcon(i),
                      color: active ? Colors.white : Colors.white24,
                      size: active ? 32 : 26,
                    ),
                  );
                }),
              ),

              // Glass Pane
              Positioned(
                left: currentLeft,
                top: 0, bottom: 0,
                width: glassW,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      // Physics
                      double vFactor = details.delta.dx.abs() * 0.01;
                      _stretchX = (1.0 + vFactor).clamp(1.0, 1.3);
                      _squashY = (1.0 - vFactor * 0.4).clamp(0.8, 1.0);

                      // Position
                      double deltaNorm = details.delta.dx / maxOffset;
                      _dragNorm = (_dragNorm + deltaNorm).clamp(0.0, 1.0);
                      _visualNorm = _applyMagnet(_dragNorm);
                      _activeIndex = (_visualNorm * 3).round();
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    setState(() {
                      _stretchX = 1.0; _squashY = 1.0;
                      _dragNorm = (_visualNorm * 3).round() / 3.0;
                      _visualNorm = _dragNorm;
                    });
                  },
                  child: _buildGlass(glassW, navHeight, screenSize),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGlass(double w, double h, Size screenSize) {
    Offset globalPos = Offset.zero;
    final RenderBox? box = _navKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      Offset navPos = box.localToGlobal(Offset.zero);
      double maxOffset = box.size.width - w;
      globalPos = navPos + Offset(_visualNorm * maxOffset, 0);
    }

    return CustomPaint(
      size: Size(w, h),
      painter: _LabGlassPainter(
        shaderProgram: _shaderProgram!,
        time: _time,
        itemPos: globalPos,
        screenSize: screenSize,
        stretchX: _stretchX,
        squashY: _squashY,
        // TRUYỀN PARAM VÀO PAINTER
        refraction: _refraction,
        specular: _specular,
        opacity: _opacity,
        frost: _frost,
        chroma: _chroma,
      ),
    );
  }

  Widget _buildSlider(String label, double val, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text(val.toStringAsFixed(2), style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.cyan,
            thumbColor: Colors.white,
            overlayColor: Colors.cyan.withOpacity(0.2),
          ),
          child: Slider(
            value: val,
            min: min,
            max: max,
            onChanged: (v) => setState(() => onChanged(v)),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

// --- PAINTERS ---

class _LabGlassPainter extends CustomPainter {
  final ui.FragmentProgram shaderProgram;
  final double time;
  final Offset itemPos;
  final Size screenSize;
  final double stretchX, squashY;
  // Params
  final double refraction, specular, opacity, frost, chroma;

  _LabGlassPainter({
    required this.shaderProgram,
    required this.time,
    required this.itemPos,
    required this.screenSize,
    required this.stretchX,
    required this.squashY,
    required this.refraction,
    required this.specular,
    required this.opacity,
    required this.frost,
    required this.chroma,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = shaderProgram.fragmentShader();
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, refraction); // Gán Refraction vào vị trí cũ của variant
    shader.setFloat(4, screenSize.width);
    shader.setFloat(5, screenSize.height);
    shader.setFloat(6, itemPos.dx);
    shader.setFloat(7, itemPos.dy);
    shader.setFloat(8, stretchX);
    shader.setFloat(9, squashY);
    // Các param mới (Index 10 trở đi)
    shader.setFloat(10, specular);
    shader.setFloat(11, opacity);
    shader.setFloat(12, frost);
    shader.setFloat(13, chroma);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = shader);
  }
  @override
  bool shouldRepaint(covariant _LabGlassPainter old) => true;
}

class _LabBackgroundPainter extends CustomPainter {
  final ui.FragmentProgram shaderProgram;
  final double time;
  final Size screenSize;
  _LabBackgroundPainter(this.shaderProgram, this.time, this.screenSize);
  @override
  void paint(Canvas canvas, Size size) {
    final shader = shaderProgram.fragmentShader();
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, -1.0); // Vẽ nền
    shader.setFloat(4, screenSize.width);
    shader.setFloat(5, screenSize.height);
    shader.setFloat(6, 0.0);
    shader.setFloat(7, 0.0);
    shader.setFloat(8, 1.0);
    shader.setFloat(9, 1.0);
    // Fill dummy cho các param còn lại
    shader.setFloat(10, 0.0);
    shader.setFloat(11, 0.0);
    shader.setFloat(12, 0.0);
    shader.setFloat(13, 0.0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = shader);
  }
  @override
  bool shouldRepaint(covariant _LabBackgroundPainter old) => true;
}