import 'package:flutter/material.dart';

import '../services/render_engine.dart';
import '../state/home_controller.dart';
import '../theme.dart';

/// 世界平面边长（逻辑像素）。足够大，摄像机可以自由移动取景。
const double _worldSize = 4000.0;

/// “渲染世界”：一块浅灰背景画布，渲染区放在世界原点 (0,0)，
/// 网格从原点开始并恰好与渲染区边缘对齐，原点位于渲染区左上角。
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
    // 渲染区左上角对齐世界原点 (0,0)，这样网格从原点铺开即与渲染区对齐。
    const left = 0.0;
    const top = 0.0;

    return Container(
      width: _worldSize,
      height: _worldSize,
      color: AppTheme.bg,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 淡化 HTML 帧铺在整个背景上，模拟 HTML 溢出渲染区。
          if (engine.lastSnapshot != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.08,
                child: Image.memory(engine.lastSnapshot!, fit: BoxFit.cover),
              ),
            ),
          // 渲染区：极浅边框 + 内嵌 WebView（外套 RepaintBoundary 供拍摄抓帧）。
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
          // 背景网格叠在最上层（纯取景辅助，不进视频）：
          // 从原点 (渲染区左上角) 铺开，步长整除渲染区宽高保证边缘对齐。
          Positioned.fill(
              child: CustomPaint(
                  clipBehavior: Clip.none,
                  painter: _GridPainter(rw: rw, rh: rh))),
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
            // 外套 RepaintBoundary：拍摄时引擎用它直取 WebView 当前画面（含动画）。
            IgnorePointer(
              ignoring: !interactive,
              child: RepaintBoundary(
                key: engine.captureKey,
                child:
                    RenderAreaView(engine: engine, html: controller.currentHtml),
              ),
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

/// 背景网格画笔：从原点 (渲染区左上角) 铺开，步长整除渲染区宽高，
/// 让网格线与渲染区四边完全对齐；并绘制坐标轴与原点标记。
class _GridPainter extends CustomPainter {
  _GridPainter({required this.rw, required this.rh});

  final double rw;
  final double rh;

  /// 候选步长（从大到小），取第一个能同时整除渲染区宽高的值。
  static const List<double> _steps = [
    256, 240, 224, 200, 160, 128, 120, 96, 80, 64, 60, 48, 40, 32, 24, 20, 16,
  ];

  double get _step {
    for (final s in _steps) {
      if (rw % s == 0 && rh % s == 0) return s;
    }
    return 80;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final step = _step;
    final gridPaint = Paint()
      ..color = const Color(0x0D000000)
      ..strokeWidth = 1;
    // 网格线从原点开始铺满整个世界（第一条线在原点上，所以从 step 起画）。
    var x = step;
    while (x <= size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      x += step;
    }
    var y = step;
    while (y <= size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      y += step;
    }
    // 坐标轴沿渲染区顶边(向右)与左边(向下)延伸，正好落在渲染区的角上。
    final axis = Paint()
      ..color = const Color(0x408B8B95)
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(0, 0), Offset(rw, 0), axis);
    canvas.drawLine(Offset(0, 0), Offset(0, rh), axis);
    // 轴方向箭头（放在渲染区右上角 / 左下角）。
    _arrow(canvas, Offset(rw, 0), Offset(rw - 10, -4), Offset(rw - 10, 4), axis);
    _arrow(canvas, Offset(0, rh), Offset(-4, rh - 10), Offset(4, rh - 10), axis);
    // 原点标记：小圆点 + “0,0” 标签（画在原点右下方，渲染区左上角内侧，保证可见）。
    canvas.drawCircle(Offset.zero, 3, Paint()..color = const Color(0x808B8B95));
    final tp = TextPainter(
      text: const TextSpan(
        text: '0,0',
        style: TextStyle(
            color: Color(0x998B8B95), fontSize: 10, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(4, 4));
  }

  void _arrow(Canvas canvas, Offset tip, Offset a, Offset b, Paint paint) {
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.rw != rw || oldDelegate.rh != rh;
}