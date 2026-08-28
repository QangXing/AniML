import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_theme.dart';
import '../models/editor_mode.dart';
import '../models/render_config.dart';
import '../services/frame_sampler.dart';
import '../services/free_transform_recognizer.dart';
import '../state/render_controller.dart';

/// 渲染舞台：承载 HTML 的 WebView 画布 + 叠加的“渲染区”（屏幕模拟窗口）。
///
/// - WebView 铺满整个舞台，HTML 在窗口内外同时显示；
/// - 渲染区是一个浅边框矩形，模拟“屏幕”；
/// - 搜索模式下可在页面视图上自由平移 / 缩放 / 旋转；
/// - 更改/拍摄模式会切换叠加层。
class RenderStage extends StatefulWidget {
  const RenderStage({
    super.key,
    required this.controller,
  });

  final RenderController controller;

  @override
  State<RenderStage> createState() => RenderStageState();
}

class RenderStageState extends State<RenderStage> {
  WebViewController? _web;
  Size? _stageSize;

  RenderController get rc => widget.controller;

  @override
  void initState() {
    super.initState();
    _initWebView();
    widget.controller.addListener(_markNeeds);
  }

  void _initWebView() {
    final old = _web;
    if (old != null) {
      // 释放旧控制器，避免平台视图泄漏
      old.dispose();
      _web = null;
    }
    final html = rc.config.html;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..loadHtmlString(html, baseUrl: 'about:blank');
    _web = controller;
  }

  @override
  void didUpdateWidget(covariant RenderStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.config.html != widget.controller.config.html) {
      // 导入新 HTML 后重载
      _initWebView();
    }
  }

  /// 抓取渲染区当前实时像素，重采样到 [width]x[height] 并返回 JPG 字节。
  ///
  /// [width]/[height] 缺省时使用配置的输出分辨率。
  Future<Uint8List?> produceFrame({int? width, int? height}) async {
    final web = _web;
    final stage = _stageSize;
    if (web == null || stage == null) return null;
    final bytes = await web.takeScreenshot();
    if (bytes == null) return null;

    final cfg = rc.config;
    final outW = width ?? cfg.outputW;
    final outH = height ?? cfg.outputH;
    final center = Offset(stage.width / 2, stage.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: cfg.displayW,
      height: cfg.displayH,
    );
    return FrameSampler.sample(
      bytes,
      stageSize: stage,
      renderRect: rect,
      offset: cfg.offset,
      scale: cfg.scale,
      rotation: cfg.rotation,
      outputWidth: outW,
      outputHeight: outH,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = rc.config;
    return LayoutBuilder(builder: (context, constraints) {
      final stage = Size(constraints.maxWidth, constraints.maxHeight);
      if (stage.width > 0) _stageSize = stage;
      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCanvas(stage, cfg),
            _buildWindow(cfg),
            if (rc.mode == EditorMode.search) _buildSearchOverlay(),
          ],
        ),
      );
    });
  }

  // 页面画布：WebView 整体被平移 / 缩放 / 旋转。
  Widget _buildCanvas(Size stage, RenderConfig cfg) {
    final content = widget.innerHTMLReady
        ? _web != null
            ? WebViewWidget(controller: _web!)
            : const SizedBox.shrink()
        : const _PlaceholderHint();

    final canvas = Container(
      width: stage.width,
      height: stage.height,
      color: Colors.white,
      child: content,
    );

    // 组合变换：q = offset + R(rotation)·S(scale)·p，绕画布左上角(0,0)旋转缩放，
    // 与 FrameSampler 逆变换保持一致。
    final transformed = Transform.translate(
      offset: cfg.offset,
      child: Transform.rotate(
        angle: cfg.rotation,
        child: Transform.scale(
          scale: cfg.scale,
          child: canvas,
        ),
      ),
    );
    return transformed;
  }

  // 渲染区窗口：浅边框矩形 + 尺寸标签（HTML 在其四周继续可见）。
  Widget _buildWindow(RenderConfig cfg) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _WindowPainter(
          windowSize: Size(cfg.displayW, cfg.displayH),
          label: '渲染区 ${cfg.displayW.round()}×${cfg.displayH.round()}',
          badge: '${cfg.outputW}×${cfg.outputH} px',
          accent: rc.mode == EditorMode.shoot,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  // 搜索模式：可命中测试的覆盖层，用于手势 + 旋转滑杆。
  Widget _buildSearchOverlay() {
    return Stack(
      children: [
        // 手势拦截层（半透明以确认命中，避免穿透到平台视图）
        Positioned.fill(
          child: RawGestureDetector(
            gestures: <Type, GestureRecognizerFactory>{
              FreeTransformRecognizer: GestureRecognizerFactoryWithHandlers<FreeTransformRecognizer>(
                () => FreeTransformRecognizer(readBase: _readTransform, onUpdate: _applyTransform),
                (FreeTransformRecognizer g) {},
              ),
            },
            child: Container(color: Colors.transparent),
          ),
        ),
        // 顶部提示
        const Positioned(
          top: 18,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(child: _SearchHint()),
          ),
        ),
        // 右侧旋转滑杆 + 复位
        Positioned(
          right: 24,
          top: 0,
          bottom: 0,
          child: Align(
            alignment: Alignment.centerRight,
            child: _RotationDial(
              value: rc.config.rotation,
              onChanged: (deg) {
                if (mounted) rc.setRotation(deg * 3.14159265 / 180);
              },
              onReset: () {
                if (mounted) rc.resetTransform();
              },
            ),
          ),
        ),
      ],
    );
  }

  // 手势基准：读取当前绝对变换（实时，取自配置）。
  FreeTransformState _readTransform() {
    final c = rc.config;
    return FreeTransformState(
      offset: c.offset,
      scale: c.scale,
      rotation: c.rotation,
    );
  }

  // 手势更新：写回配置并触发重建。
  void _applyTransform(FreeTransformState s) {
    if (!mounted) return;
    rc.setTransform(TransformDelta(
      offset: s.offset,
      scale: s.scale,
      rotation: s.rotation,
    ));
  }

  bool _listening = false;
  void _markNeeds() {
    if (!_listening) {
      _listening = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _listening = false;
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_markNeeds);
    _web?.dispose();
    super.dispose();
  }
}

extension on RenderStage {
  bool get innerHTMLReady => controller.config.html.isNotEmpty;
}

class _PlaceholderHint extends StatelessWidget {
  const _PlaceholderHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '导入 HTML 后在此渲染',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: AppTheme.glassDecoration(radius: 20),
      child: const Text(
        '拖动平移 · 双指缩放 / 旋转 · 右侧滑杆精确旋转',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
    );
  }
}

/// 渲染区窗口的浅边框绘制。
class _WindowPainter extends CustomPainter {
  const _WindowPainter({
    required this.windowSize,
    required this.label,
    required this.badge,
    required this.accent,
  });

  final Size windowSize;
  final String label;
  final String badge;
  final bool accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(center: center, width: windowSize.width, height: windowSize.height);

    // 极浅的填充，让窗口在浅背景上稍稍可辨
    final fill = Paint()
      ..color = accent ? const Color(0x0A5B7CFA) : const Color(0x0DFFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      fill,
    );

    // 很浅但清晰的边框
    final border = Paint()
      ..color = accent ? AppTheme.accent : const Color(0x33B0B6C0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.8), const Radius.circular(6)),
      border,
    );

    // 四角小标记
    final corner = Paint()
      ..color = AppTheme.pureGrey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const len = 14.0;
    void cornerLine(Offset a, Offset b) => canvas.drawLine(a, b, corner);
    cornerLine(rect.topLeft, rect.topLeft + const Offset(len, 0));
    cornerLine(rect.topLeft, rect.topLeft + const Offset(0, len));
    cornerLine(rect.topRight, rect.topRight + const Offset(-len, 0));
    cornerLine(rect.topRight, rect.topRight + const Offset(0, len));
    cornerLine(rect.bottomLeft, rect.bottomLeft + const Offset(len, 0));
    cornerLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -len));
    cornerLine(rect.bottomRight, rect.bottomRight + const Offset(-len, 0));
    cornerLine(rect.bottomRight, rect.bottomRight + const Offset(0, -len));

    // 顶部标签
    final textStyle = TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 11,
      foreground: Paint()..color = AppTheme.textSecondary,
    );
    final labelPainter = TextPainter(
      text: TextSpan(text: '$label  ·  $badge', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    final labelPos = Offset(
      (size.width - labelPainter.width) / 2,
      (center.dy - windowSize.height / 2) - labelPainter.height - 6,
    );
    labelPainter.paint(canvas, labelPos);
  }

  @override
  bool shouldRepaint(covariant _WindowPainter old) =>
      old.windowSize != windowSize ||
      old.label != label ||
      old.badge != badge ||
      old.accent != accent;
}

/// 精确旋转滑杆。
class _RotationDial extends StatelessWidget {
  const _RotationDial({required this.value, required this.onChanged, required this.onReset});

  final double value; // 弧度
  final ValueChanged<double> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final deg = (value * 180 / 3.14159265) % 360;
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassDecoration(radius: 16, fill: const Color(0x99FFFFFF)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.rotate_right, size: 16, color: AppTheme.pureGrey),
              const SizedBox(width: 6),
              Text('${deg.round()}°', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                value: deg,
                min: 0,
                max: 360,
                onChanged: (d) => onChanged(d),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt, size: 16, color: AppTheme.pureGrey),
            label: const Text('复位', style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }
}