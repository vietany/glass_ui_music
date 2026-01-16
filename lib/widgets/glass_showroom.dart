import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../utils/nav_config.dart';

class GlassShowroom extends StatefulWidget {
  const GlassShowroom({super.key});

  @override
  State<GlassShowroom> createState() => _GlassShowroomState();
}

class _GlassShowroomState extends State<GlassShowroom> with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _shaderProgram;
  late Ticker _ticker;
  double _time = 0.0;

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

  @override
  Widget build(BuildContext context) {
    if (_shaderProgram == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          Positioned.fill(
              child: CustomPaint(
                painter: _BackgroundDummyPainter(_shaderProgram!, _time, screenSize),
              )
          ),
          Column(
            children: [
              Container(
                padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 20,
                    bottom: 20, left: 20, right: 20
                ),
                width: double.infinity,
                color: Colors.black.withOpacity(0.6),
                child: Column(
                  children: const [
                    Text(
                      "SHOWROOM KÍNH PHẲNG",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Thử kéo nhanh để thấy kính biến dạng (Lỏng)\nDi chuyển chậm qua Icon để thấy điểm neo (Hút)",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                  itemCount: 10,
                  separatorBuilder: (_, __) => const SizedBox(height: 30),
                  itemBuilder: (context, index) {
                    return _DemoNavBarItem(
                      index: index,
                      shaderProgram: _shaderProgram!,
                      time: _time,
                      screenSize: screenSize,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DemoNavBarItem extends StatefulWidget {
  final int index;
  final ui.FragmentProgram shaderProgram;
  final double time;
  final Size screenSize;

  const _DemoNavBarItem({
    super.key,
    required this.index,
    required this.shaderProgram,
    required this.time,
    required this.screenSize,
  });

  @override
  State<_DemoNavBarItem> createState() => _DemoNavBarItemState();
}

class _DemoNavBarItemState extends State<_DemoNavBarItem> {
  double _dragNorm = 0.0; // Vị trí thô (Raw Position)
  double _visualNorm = 0.0; // Vị trí hiển thị (Sau khi qua xử lý nam châm)
  int _activeIndex = 0;

  // Biến vật lý
  double _velocity = 0.0;
  double _stretchX = 1.0;
  double _squashY = 1.0;

  final GlobalKey _key = GlobalKey();

  final List<String> _names = [
    "Standard", "Super Clear", "Reflective", "Frosted",
    "Prism", "Ocean Blue", "Amber Gold",
    "Acrylic", "Smoked Dark", "Apple Liquid"
  ];

  // HÀM TÍNH TOÁN LỰC HÚT NAM CHÂM (MAGNETIC SNAP)
  double _applyMagnetPhysics(double rawNorm) {
    // Có 4 tab, các điểm neo là 0.0, 0.33, 0.66, 1.0
    // Ta nhân 3 để được không gian 0..3
    double scaled = rawNorm * 3.0;

    // Tìm điểm neo gần nhất (Integer gần nhất)
    double anchor = scaled.roundToDouble();

    // Khoảng cách từ vị trí hiện tại đến điểm neo
    double dist = scaled - anchor;

    // Áp dụng lực hút: Nếu ở gần điểm neo (|dist| < 0.25), lực hút sẽ kéo nó về anchor
    // Dùng hàm sin để tạo đường cong mềm mại
    // Hệ số 0.15 là độ mạnh của lực hút
    double magneticPull = -apiSin(dist * 3.14159) * 0.15;

    // Cộng lực hút vào vị trí gốc
    double result = scaled + magneticPull;

    return result / 3.0; // Trả về lại không gian 0..1
  }

  double apiSin(double x) => x - (x*x*x)/6; // Xấp xỉ Sin cho nhanh

  @override
  Widget build(BuildContext context) {
    const double navHeight = 70;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 10),
          child: Text(
            "${widget.index + 1}. ${_names[widget.index]}",
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),

        Container(
          key: _key,
          height: navHeight,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: Colors.white10),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              double totalWidth = constraints.maxWidth;
              double glassWidth = totalWidth / 4;
              double maxOffset = totalWidth - glassWidth;

              // Sử dụng _visualNorm để hiển thị (đã có lực hút)
              double currentLeft = _visualNorm * maxOffset;

              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Row(
                    children: List.generate(4, (i) {
                      bool isActive = _activeIndex == i;
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            NavConfig.getIcon(i),
                            color: isActive ? Colors.white : Colors.white24,
                            size: isActive ? 28 : 24,
                          ),
                        ),
                      );
                    }),
                  ),

                  Positioned(
                    left: currentLeft,
                    top: 0, bottom: 0,
                    width: glassWidth,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          // 1. Tính vận tốc (Pixel/frame) -> Độ biến dạng
                          // Kéo càng nhanh, velocity càng lớn
                          _velocity = details.delta.dx;

                          // Stretch: 1.0 + vận tốc (max 1.3)
                          // Squash: 1.0 - vận tốc (min 0.8)
                          double vFactor = _velocity.abs() * 0.015; // Hệ số nhạy
                          _stretchX = (1.0 + vFactor).clamp(1.0, 1.4);
                          _squashY = (1.0 - vFactor * 0.5).clamp(0.75, 1.0);

                          // 2. Cập nhật vị trí thô
                          double deltaNorm = details.delta.dx / maxOffset;
                          _dragNorm = (_dragNorm + deltaNorm).clamp(0.0, 1.0);

                          // 3. Áp dụng Lực hút Nam châm cho Visual
                          _visualNorm = _applyMagnetPhysics(_dragNorm);

                          // 4. Update Active Tab
                          _activeIndex = (_visualNorm * 3).round();
                        });
                      },
                      onHorizontalDragEnd: (details) {
                        setState(() {
                          // Khi thả tay, reset biến dạng về bình thường
                          _stretchX = 1.0;
                          _squashY = 1.0;
                          _velocity = 0.0;

                          // Snap cứng vào tab gần nhất (để khỏi lơ lửng)
                          _dragNorm = (_visualNorm * 3).round() / 3.0;
                          _visualNorm = _dragNorm;
                        });
                      },
                      child: _buildGlassPane(glassWidth, navHeight),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGlassPane(double width, double height) {
    Offset globalPos = Offset.zero;
    final RenderBox? renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      Offset navPos = renderBox.localToGlobal(Offset.zero);
      double maxOffset = renderBox.size.width - width;
      globalPos = navPos + Offset(_visualNorm * maxOffset, 0);
    }

    return CustomPaint(
      size: Size(width, height),
      painter: _FlatGlassPainter(
        shaderProgram: widget.shaderProgram,
        variantIndex: widget.index,
        time: widget.time,
        itemPosition: globalPos,
        screenSize: widget.screenSize,
        stretchX: _stretchX, // Truyền biến dạng vào painter
        squashY: _squashY,
      ),
    );
  }
}

class _FlatGlassPainter extends CustomPainter {
  final ui.FragmentProgram shaderProgram;
  final int variantIndex;
  final double time;
  final Offset itemPosition;
  final Size screenSize;
  // Thêm tham số biến dạng
  final double stretchX;
  final double squashY;

  _FlatGlassPainter({
    required this.shaderProgram,
    required this.variantIndex,
    required this.time,
    required this.itemPosition,
    required this.screenSize,
    required this.stretchX,
    required this.squashY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = shaderProgram.fragmentShader();
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, variantIndex.toDouble());
    shader.setFloat(4, screenSize.width);
    shader.setFloat(5, screenSize.height);
    shader.setFloat(6, itemPosition.dx);
    shader.setFloat(7, itemPosition.dy);
    // Thêm Stretch & Squash (Index 8 và 9)
    shader.setFloat(8, stretchX);
    shader.setFloat(9, squashY);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = shader);
  }
  @override
  bool shouldRepaint(covariant _FlatGlassPainter oldDelegate) => true;
}

class _BackgroundDummyPainter extends CustomPainter {
  final ui.FragmentProgram shaderProgram;
  final double time;
  final Size screenSize;

  _BackgroundDummyPainter(this.shaderProgram, this.time, this.screenSize);

  @override
  void paint(Canvas canvas, Size size) {
    final shader = shaderProgram.fragmentShader();
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, -1.0);
    shader.setFloat(4, screenSize.width);
    shader.setFloat(5, screenSize.height);
    shader.setFloat(6, 0.0);
    shader.setFloat(7, 0.0);
    // Dummy stretch cho background
    shader.setFloat(8, 1.0);
    shader.setFloat(9, 1.0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = shader);
  }
  @override
  bool shouldRepaint(covariant _BackgroundDummyPainter oldDelegate) => true;
}