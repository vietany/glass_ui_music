import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../utils/nav_config.dart';
import 'water_drop_overlay.dart';

class LiquidNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const LiquidNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<LiquidNavBar> createState() => _LiquidNavBarState();
}

class _LiquidNavBarState extends State<LiquidNavBar> with TickerProviderStateMixin {
  late AnimationController _physicsController;
  late AnimationController _scaleController;
  ui.FragmentProgram? _fragmentProgram;

  // Cờ đánh dấu đang kéo để chặn xung đột animation
  bool _isDragging = false;

  final _springDesc = const SpringDescription(
      mass: 1.0,
      stiffness: 100.0,
      damping: 18.0
  );

  @override
  void initState() {
    super.initState();
    _loadShader();

    _physicsController = AnimationController.unbounded(vsync: this);
    _physicsController.value = widget.currentIndex.toDouble();

    _scaleController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
        lowerBound: 1.0,
        upperBound: 1.1
    );
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/flat_glass_collection.frag');
      setState(() => _fragmentProgram = program);
    } catch (e) {
      debugPrint("Shader Error: $e");
    }
  }

  @override
  void didUpdateWidget(LiquidNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // CHỈ CHẠY ANIMATION KHI KHÔNG KÉO
    // Nếu đang kéo (_isDragging == true), ta để ngón tay người dùng tự kiểm soát vị trí,
    // không cho lò xo can thiệp vào lúc này.
    if (!_isDragging && oldWidget.currentIndex != widget.currentIndex) {
      final simulation = SpringSimulation(
          _springDesc,
          _physicsController.value,
          widget.currentIndex.toDouble(),
          _physicsController.velocity
      );
      _physicsController.animateWith(simulation);
    }
  }

  @override
  void dispose() {
    _physicsController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  // --- GESTURE LOGIC (REAL-TIME UPDATE) ---

  void _onDragStart(DragStartDetails d) {
    _isDragging = true; // Bắt đầu kéo
    _scaleController.forward();
  }

  void _onDragUpdate(DragUpdateDetails d, double tabWidth) {
    // 1. Cập nhật vị trí giọt nước theo ngón tay
    double newPos = (d.localPosition.dx / tabWidth).clamp(0.0, NavConfig.count - 1.0);
    _physicsController.value = newPos;

    // 2. TÍNH TOÁN CHUYỂN TAB THỜI GIAN THỰC
    // Làm tròn vị trí để biết đang ở gần tab nào nhất
    int targetIndex = newPos.round();

    // Nếu vị trí ngón tay đã sang tab khác -> Gọi onTap ngay lập tức
    if (targetIndex != widget.currentIndex) {
      widget.onTap(targetIndex);
      // MainScreen sẽ nhận được index mới -> PageView chuyển trang -> LiquidNavBar được rebuild
      // Nhưng nhờ cờ _isDragging = true, animation lò xo sẽ không chạy, tránh giật.
    }
  }

  void _onDragEnd(DragEndDetails d, double tabWidth) {
    _isDragging = false; // Kết thúc kéo
    _scaleController.reverse();

    // Snap giọt nước vào chính giữa tab hiện tại (để nó đẹp)
    int targetIndex = _physicsController.value.round();

    // Đảm bảo đồng bộ lần cuối
    if (targetIndex != widget.currentIndex) {
      widget.onTap(targetIndex);
    }

    // Chạy lò xo để giọt nước "hít" vào tâm tab
    final simulation = SpringSimulation(
        _springDesc,
        _physicsController.value,
        targetIndex.toDouble(),
        d.velocity.pixelsPerSecond.dx / tabWidth * 0.5
    );
    _physicsController.animateWith(simulation);
  }

  void _onTapUp(TapUpDetails d, double tabWidth) {
    int newIndex = (d.localPosition.dx / tabWidth).floor().clamp(0, NavConfig.count - 1);
    widget.onTap(newIndex);
  }

  @override
  Widget build(BuildContext context) {
    const double navHeight = 70.0;

    return Container(
      height: navHeight + 20,
      alignment: Alignment.topCenter,
      child: Container(
        height: navHeight,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2), // Nền tối hơn chút để kính nổi bật
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: Colors.white10),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // LỚP 1: ICONS
            LayoutBuilder(
                builder: (context, constraints) {
                  double tabWidth = constraints.maxWidth / NavConfig.count;
                  return Row(
                    children: List.generate(NavConfig.count, (index) {
                      return SizedBox(
                        width: tabWidth,
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _physicsController,
                            builder: (context, child) {
                              // Logic highlight thời gian thực
                              // Tab nào đang được chọn (currentIndex) thì sáng
                              bool isActive = index == widget.currentIndex;
                              return Icon(
                                NavConfig.getIcon(index),
                                color: isActive ? Colors.white : Colors.white24,
                                size: isActive ? 28 : 24,
                              );
                            },
                          ),
                        ),
                      );
                    }),
                  );
                }
            ),

            // LỚP 2: GESTURE (Nằm trên icon nhưng dưới kính để bắt sự kiện tốt nhất)
            LayoutBuilder(
                builder: (context, constraints) {
                  double tabWidth = constraints.maxWidth / NavConfig.count;
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: _onDragStart,
                    onHorizontalDragUpdate: (d) => _onDragUpdate(d, tabWidth),
                    onHorizontalDragEnd: (d) => _onDragEnd(d, tabWidth),
                    onHorizontalDragCancel: () {
                      _isDragging = false;
                      _scaleController.reverse();
                    },
                    onTapUp: (d) => _onTapUp(d, tabWidth),
                    child: Container(color: Colors.transparent),
                  );
                }
            ),

            // LỚP 3: KHỐI KÍNH (Overlay) - CHỌN MẪU APPLE LIQUID (SỐ 10 - index 9)
            IgnorePointer(
              child: LayoutBuilder(
                  builder: (context, constraints) {
                    return AnimatedBuilder(
                        animation: Listenable.merge([_physicsController, _scaleController]),
                        builder: (context, child) {
                          double centerNorm = (_physicsController.value + 0.5) / NavConfig.count;

                          double v = _physicsController.velocity.abs() / 2500;
                          double stretchX = (1.0 + v * 0.05).clamp(1.0, 1.1);
                          double squashY = (1.0 - v * 0.02).clamp(0.95, 1.0);

                          return SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: WaterDropOverlay(
                              shaderProgram: _fragmentProgram,
                              centerNormalized: centerNorm,
                              stretchX: stretchX,
                              squashY: squashY,
                              scale: _scaleController.value,
                            ),
                          );
                        }
                    );
                  }
              ),
            ),
          ],
        ),
      ),
    );
  }
}