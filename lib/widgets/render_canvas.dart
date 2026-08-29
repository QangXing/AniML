import 'package:flutter/material.dart';

import '../services/render_engine.dart';
import '../state/home_controller.dart';
import '../theme.dart';

/// 世界平面边长（逻辑像素）。足够大，摄像机可以自由移动取景。
const double _worldSize = 4000.0;

/// “渲染世界”：一块浅灰背景画布，中间是带浅色边框的渲染区，上面实时承载 HTML。
/// 渲染背景既当作被拍对象，也承载一个淡化版的 HTML 帧，表现“HTML 也在渲染区外”。
class RenderCanvas extends StatelessWidget {
  const RenderCanvas(
      {super.key,
      required this.controller,
      required this.engine,
      this.interactive = true});

  final HomeController controller;
  final RenderEngine engine;

  /// 是否允许与 HTML 交互（搜索模式下关闭，便于相机手势）。
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final cfg = controller.config;
    final rw = cfg.displayWidth;
    final rh = cfg.displayHeight;
    // 渲染区放在世界中心
    final left = (_worldSize - rw) / 2;
    final top = (_worldSize - rh) / 2;

    return Container(
      width: _worldSize,
      height: _worldSize,
      color: AppTheme.bg,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 背景网格：提示这是一个可以被相机拍摄的“世界”。
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          // 淡化 HTML 帧铺在整个背景上，模拟 HTML 溢出渲染区。
          if (engine.lastSnapshot != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.08,
                child: Image.memory(engine.lastSnapshot!, fit: BoxFit.cover),
              ),
            ),
          // 渲染区：极浅边框 + 内嵌 WebView。
          Positioned(
            left: left,
            top: top,
            width: rw,
            height: rh,
            child: _RenderAreaBox(
              controller: controller,
              engine: engine,
              interactive: interactive,
              showSnapPlaceholder: engine.lastSnapshot != null,
            ),
          ),
        ],
      ),
    );
  }
}

class _RenderAreaBox extends StatelessWidget {
  const _RenderAreaBox({
    required this.controller,
    required this.engine,
    required this.interactive,
    required this.showSnapPlaceholder,
  });

  final HomeController controller;
  final RenderEngine engine;
  final bool interactive;
  final bool showSnapPlaceholder;

  @override
  Widget build(BuildContext context) {
    final cfg = controller.config;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x55B8B8BE), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!controller.hasHtml)
            const Center(
              child: Text('导入 HTML 后在此渲染',
                  style: TextStyle(color: AppTheme.subInk, fontSize: 14)),
            )
          else ...[
            // 只要有 HTML 就挂载 WebView，触发引擎加载；否则引擎永远不会收到加载请求。
            IgnorePointer(
              ignoring: !interactive,
              child: RenderAreaView(engine: engine, html: controller.currentHtml),
            ),
            // 页面加载完成前显示加载态（引擎 isReady 由 onPageFinished 置位）。
            if (!engine.isReady)
              const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.subInk, strokeWidth: 2),
              ),
          ],
          // 左上角尺寸标注
          Positioned(
            left: 6,
            top: 4,
            child: IgnorePointer(
              child: Text(
                '${cfg.pixelWidth} × ${cfg.pixelHeight}px',
                style: const TextStyle(
                  color: Color(0x66FFFFFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 背景网格画笔。
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0x0D000000)
      ..strokeWidth = 1;
    const step = 80.0;
    var x = 0.0;
    while (x <= size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      x += step;
    }
    var y = 0.0;
    while (y <= size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      y += step;
    }
    // 相机世界中心十字
    final c = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 3;
    canvas.drawLine(
        Offset(size.width / 2, 0), Offset(size.width / 2, size.height), c);
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), c);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}