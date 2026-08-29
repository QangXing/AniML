import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../services/render_engine.dart';
import '../state/home_controller.dart';
import 'render_canvas.dart';

/// 手机显示屏内部的“摄像机视口”。
/// 把渲染世界投影到屏幕，并支持在搜索模式下平移 / 缩放 / 旋转镜头。
class CameraViewport extends StatefulWidget {
  const CameraViewport({
    super.key,
    required this.controller,
    required this.engine,
  });

  final HomeController controller;
  final RenderEngine engine;

  @override
  State<CameraViewport> createState() => _CameraViewportState();
}

class _CameraViewportState extends State<CameraViewport> {
  Camera? _startCam;
  Offset _startFocal = Offset.zero;

  bool get _canGesture => widget.controller.mode == Mode.search;

  /// 世界坐标 -> 平移到屏幕的逆映射辅助。
  Offset _toWorld(Matrix4 m, Offset screen) {
    final v = m.clone()..invert();
    final r = v.transform3(Vector3(screen.dx, screen.dy, 1.0));
    return Offset(r.x, r.y);
  }

  void _onScaleStart(ScaleStartDetails d) {
    if (!_canGesture) return;
    _startCam = widget.controller.camera;
    _startFocal = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d, Size sz) {
    if (!_canGesture) return;
    final start = _startCam ?? widget.controller.camera;
    final sc = (start.scale * d.scale).clamp(0.03, 10.0).toDouble();
    // 旋转不再跟随手势：只在工具箱中设置 0/90/180/270/360 档位。
    final rot = start.rotation;

    // 起始焦点对应的世界点
    final m0 = start.worldToScreen(sz);
    final w0 = _toWorld(m0, _startFocal);

    // 让该世界点现在仍落在当前焦点下
    final u = Offset((d.localFocalPoint.dx - sz.width / 2) / sc,
        (d.localFocalPoint.dy - sz.height / 2) / sc);
    final cr = math.cos(-rot), sr = math.sin(-rot);
    final ru = Offset(u.dx * cr - u.dy * sr, u.dx * sr + u.dy * cr);
    final p = w0 - ru;

    widget.controller.updateCamera(
      start.copyWith(position: p, scale: sc, rotationDegrees: start.rotationDegrees),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Listener(
      onPointerSignal: (e) {},
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _onScaleStart,
        onScaleUpdate: (d) => _onScaleUpdate(d, size),
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final c = widget.controller.camera;
            return Transform(
              alignment: Alignment.center,
              transform: c.worldToScreen(size),
              child: RenderCanvas(
                controller: widget.controller,
                engine: widget.engine,
                interactive: widget.controller.mode != Mode.search,
              ),
            );
          },
        ),
      ),
    );
  }
}