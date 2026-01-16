import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../utils/nav_config.dart';
import 'glass_data.dart';
import 'glass_painters.dart';

class DemoNavBar extends StatefulWidget {
  final GlassVariant data;
  final ui.FragmentProgram shaderProgram;
  final double time;
  final Size screenSize;

  const DemoNavBar({
    super.key,
    required this.data,
    required this.shaderProgram,
    required this.time,
    required this.screenSize,
  });

  @override
  State<DemoNavBar> createState() => _DemoNavBarState();
}

class _DemoNavBarState extends State<DemoNavBar> {
  final GlobalKey _key = GlobalKey();

  // State quản lý vị trí và vật lý
  double _dragNorm = 0.0;    // 0.0 -> 1.0 (Vị trí thực tế ngón tay)
  double _visualNorm = 0.0;  // 0.0 -> 1.0 (Vị trí hiển thị sau khi qua nam châm)
  int _activeIndex = 0;

  double _velocity = 0.0;
  double _stretchX = 1.0;
  double _squashY = 1.0;

  // Logic Nam châm (Magnetic Snap)
  double _applyMagnetPhysics(double rawNorm) {
    double scaled = rawNorm * 3.0; // 4 tab -> không gian 0..3
    double anchor = scaled.roundToDouble();
    double dist = scaled - anchor;
    // Lực hút
    double magneticPull = -_apiSin(dist * 3.14159) * 0.15;
    return (scaled + magneticPull) / 3.0;
  }

  double _apiSin(double x) => x - (x*x*x)/6; // Fast Sine approximation

  @override
  Widget build(BuildContext context) {
    const double navHeight = 70;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tiêu đề loại kính
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 12),
          child: Row(
            children: [
              Text(
                "${widget.data.index + 1}. ${widget.data.name}",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 8),
              Text(
                widget.data.description,
                style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),

        // Thanh Navi
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
              double currentLeft = _visualNorm * maxOffset;

              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Lớp Icons
                  Row(
                    children: List.generate(4, (i) {
                      bool isActive = _activeIndex == i;
                      // Kính đen (index 8) cần icon sáng mới thấy
                      bool isDarkGlass = widget.data.index == 8;

                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            NavConfig.getIcon(i),
                            color: isActive
                                ? Colors.white
                                : (isDarkGlass ? Colors.white24 : Colors.white24),
                            size: isActive ? 28 : 24,
                          ),
                        ),
                      );
                    }),
                  ),

                  // Lớp Kính (Draggable)
                  Positioned(
                    left: currentLeft,
                    top: 0, bottom: 0,
                    width: glassWidth,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          // 1. Tính vận tốc & Biến dạng
                          _velocity = details.delta.dx;
                          double vFactor = _velocity.abs() * 0.015;
                          _stretchX = (1.0 + vFactor).clamp(1.0, 1.4);
                          _squashY = (1.0 - vFactor * 0.5).clamp(0.75, 1.0);

                          // 2. Cập nhật vị trí
                          double deltaNorm = details.delta.dx / maxOffset;
                          _dragNorm = (_dragNorm + deltaNorm).clamp(0.0, 1.0);

                          // 3. Áp dụng nam châm
                          _visualNorm = _applyMagnetPhysics(_dragNorm);

                          // 4. Active Tab
                          _activeIndex = (_visualNorm * 3).round();
                        });
                      },
                      onHorizontalDragEnd: (details) {
                        setState(() {
                          _stretchX = 1.0;
                          _squashY = 1.0;
                          // Snap về vị trí chuẩn khi thả tay
                          _dragNorm = (_visualNorm * 3).round() / 3.0;
                          _visualNorm = _dragNorm;
                        });
                      },
                      child: _buildGlass(glassWidth, navHeight),
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

  Widget _buildGlass(double width, double height) {
    // Tính tọa độ toàn cục
    Offset globalPos = Offset.zero;
    final RenderBox? renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      Offset navPos = renderBox.localToGlobal(Offset.zero);
      // Cần tính lại maxOffset ở đây để chính xác
      double maxOffset = renderBox.size.width - width;
      globalPos = navPos + Offset(_visualNorm * maxOffset, 0);
    }

    return CustomPaint(
      size: Size(width, height),
      painter: FlatGlassPainter(
        shaderProgram: widget.shaderProgram,
        variantIndex: widget.data.index,
        time: widget.time,
        itemPosition: globalPos,
        screenSize: widget.screenSize,
        stretchX: _stretchX,
        squashY: _squashY,
      ),
    );
  }
}