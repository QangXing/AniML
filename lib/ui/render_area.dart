import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/project_controller.dart';
import '../controllers/webview_pool.dart';
import '../models/anime_layer.dart';
import '../utils/constants.dart';

/// 渲染区：承载所有 WebView 层，并处理搜索模式的缩放/平移/旋转。
class RenderArea extends ConsumerStatefulWidget {
  const RenderArea({super.key});

  @override
  ConsumerState<RenderArea> createState() => _RenderAreaState();
}

class _RenderAreaState extends ConsumerState<RenderArea> {
  final Map<String, InAppWebViewController> _controllers = {};
  final Map<String, bool> _loaded = {};
  double _fitScale = 1.0;

  bool _grabbing = false;
  Offset _grabStartFocal = Offset.zero;
  double _grabStartScale = 1.0;
  double _grabStartRotation = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = ref.read(projectProvider);
      c.playheadHook = _onPlayhead;
      _applyVisibility(c);
    });
  }

  @override
  void dispose() {
    final c = ref.read(projectProvider);
    if (c.playheadHook.toString() == _onPlayhead.toString()) {
      c.playheadHook = null;
    }
    _controllers.clear();
    super.dispose();
  }

  void _onPlayhead(ProjectController c) => _applyVisibility(c);

  /// 根据播放头及条带设置各层显隐。
  void _applyVisibility(ProjectController c) {
    final active = <String>{};
    for (final clip in c.clips) {
      if (c.isClipActiveAt(clip, c.playhead)) active.add(clip.layerId);
    }
    for (final layer in c.layers) {
      final visible = layer.visible && active.contains(layer.id);
      if (_loaded[layer.id] == true && !(layer.locked)) {
        ref.read(webViewPoolProvider).setLayerVisible(layer.id, visible);
      }
    }
  }

  // 计算当前展示所需的缩放，使画布以 1:1 适配可用区域。
  void _computeFit(BoxConstraints constraints, double w, double h) {
    final availW = math.max(1.0, constraints.maxWidth);
    final availH = math.max(1.0, constraints.maxHeight);
    _fitScale = math.min(availW / w, availH / h);
  }

  @override
  Widget build(BuildContext context) {
    final proj = ref.watch(projectProvider);
    final pool = ref.watch(webViewPoolProvider);
    final w = proj.canvas.width;
    final h = proj.canvas.height;

    GestureDetector? gesture;
    if (proj.mode == AppMode.search) {
      gesture = _buildSearchGesture(proj);
    }

    Widget canvas = SizedBox(
      width: w,
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: proj.canvas.backgroundColor),
          if (proj.showGrid) _buildGrid(proj),
          for (final layer in proj.layers) _buildLayer(layer, proj, pool),
          if (proj.mode == AppMode.camera) const Positioned.fill(child: _RecOverlay()),
        ],
      ),
    );

    // 应用视口变换
    final displayScale = _fitScale * proj.viewport.scale;
    Widget transformed = Transform.translate(
      offset: Offset(proj.viewport.offsetX * _fitScale, proj.viewport.offsetY * _fitScale),
      child: Transform.rotate(
        angle: proj.viewport.rotation,
        child: Transform.scale(
          scale: displayScale,
          child: canvas,
        ),
      ),
    );

    final content = LayoutBuilder(builder: (context, constraints) {
      _computeFit(constraints, w, h);
      return Center(child: transformed);
    });

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        if (gesture != null) Positioned.fill(child: gesture),
        _buildBorder(w, h, displayScale),
      ],
    );
  }

  // ------------------------------------------------------------------ 手势
  GestureDetector _buildSearchGesture(ProjectController proj) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (d) {
        _grabbing = true;
        _grabStartFocal = d.focalPoint;
        _grabStartScale = proj.viewport.scale;
        _grabStartRotation = proj.viewport.rotation;
      },
      onScaleUpdate: (d) {
        // 缩放与旋转（双指）
        final newScale = (_grabStartScale * d.scale)
            .clamp(AppConstants.minViewportScale, AppConstants.maxViewportScale);
        final newRot = _grabStartRotation + d.rotation;
        // 以聚焦点为锚点平移
        final dx = (d.focalPoint.dx - _grabStartFocal.dx) / _fitScale;
        final dy = (d.focalPoint.dy - _grabStartFocal.dy) / _fitScale;
        proj.updateViewport(
          scale: newScale,
          rotation: newRot,
          offsetX: proj.viewport.offsetX + dx,
          offsetY: proj.viewport.offsetY + dy,
        );
      },
      onScaleEnd: (_) => _grabbing = false,
      onDoubleTap: () => proj.resetViewport(),
    );
  }

  // ------------------------------------------------------------------ 层 WebView
  Widget _buildLayer(AniLayer layer, ProjectController proj, WebViewPool pool) {
    final dim = proj.mode == AppMode.edit &&
        proj.activeLayerId != null &&
        proj.activeLayerId != layer.id;

    final web = InAppWebView(
      key: ValueKey('layer_${layer.id}'),
      initialData: InAppWebViewInitialData(
        data: layer.source,
        baseUrl: layer.assetPath != null
            ? WebUri.uri(Uri.file(layer.assetPath!))
            : null,
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
        supportZoom: false,
      ),
      gestureRecognizers: null,
      onWebViewCreated: (c) {
        _controllers[layer.id] = c;
        pool.register(layer.id, c);
      },
      onLoadStop: (c, url) async {
        if (!_loaded.containsKey(layer.id)) {
          _loaded[layer.id] = true;
          await pool.bootstrap(layer.id);
          _applyVisibility(proj);
        }
      },
    );

    return Positioned.fill(
      child: Opacity(
        opacity: layer.visible ? (dim ? 0.35 : 1.0) : 0.0,
        child: IgnorePointer(
          ignoring: proj.mode == AppMode.search || proj.mode == AppMode.camera,
          child: web,
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ 辅助
  Widget _buildGrid(ProjectController proj) {
    final step = proj.canvas.gridSize;
    return IgnorePointer(
      child: CustomPaint(painter: _GridPainter(step: step, axis: proj.showAxis)),
    );
  }

  Widget _buildBorder(double w, double h, double displayScale) {
    return IgnorePointer(
      child: Center(
        child: Transform.scale(
          scale: displayScale,
          child: SizedBox.fromSize(
            size: Size(w, h),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppConstants.renderAreaBorder, width: 1),
                boxShadow: const [
                  BoxShadow(color: Color(0x55888888), blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.step, required this.axis});
  final double step;
  final bool axis;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppConstants.gridColor
      ..strokeWidth = 0.6;
    final axisP = Paint()
      ..color = AppConstants.axisColor
      ..strokeWidth = 1.2;

    var x = step;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      x += step;
    }
    var y = step;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      y += step;
    }

    if (axis) {
      // 原点在左上角，仅绘制上边与左边轴线（坐标参考）。
      canvas.drawLine(Offset(0, 0), Offset(size.width, 0), axisP);
      canvas.drawLine(Offset(0, 0), Offset(0, size.height), axisP);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.step != step || old.axis != axis;
}

class _RecOverlay extends StatelessWidget {
  const _RecOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppConstants.recRed, width: 2),
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppConstants.recRed,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'REC',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}