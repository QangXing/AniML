import 'dart:math' as math;
import 'dart:ui' show Offset;

/// 渲染配置：渲染区（“屏幕”模拟窗口）与输出像素大小、以及页面变换。
///
/// 坐标约定（渲染与采样使用同一套）：
///  - 舞台（stage）：WebView 所在的整块内容区域，几何尺寸为 `stageSize`；
///  - 渲染区（render window）：叠加在舞台正中央的浅边框矩形，逻辑尺寸为
///    `displayW x displayH`，即模拟出来的“屏幕”；
///  - 页面变换：把整张 HTML（WebView）作为画布做
///    `q = R(rotation)·S(scale)·p + offset` 的仿射变换，使页面在浅边框
///    下方/四周自由移动、缩放、旋转（HTML 可在渲染区外渲染）。
class RenderConfig {
  RenderConfig({
    this.html = '',
    this.displayW = 320,
    this.displayH = 240,
    this.outputW = 1920,
    this.outputH = 1080,
    this.offset = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  /// 待渲染的 HTML 源码。
  String html;

  /// 渲染区窗口在屏幕上的逻辑宽度 / 高度（可调）。
  double displayW;
  double displayH;

  /// 输出像素宽 / 高（拍摄时最终画面的分辨率）。
  int outputW;
  int outputH;

  /// 页面变换：平移 / 缩放 / 旋转。
  Offset offset;
  double scale;
  double rotation; // 弧度

  /// 是否锁定长宽比（更改模式下按比例联动）。
  bool lockAspect = true;

  double get aspect => displayW / displayH;

  /// 把一份 HTML 页面坐标 `p`（逻辑，原点=舞台中心）变换到舞台坐标 `q`。
  Offset forward(Offset p) {
    final c = math.cos(rotation);
    final s = math.sin(rotation);
    final rx = p.dx * scale;
    final ry = p.dy * scale;
    return Offset(
      rx * c - ry * s + offset.dx,
      rx * s + ry * c + offset.dy,
    );
  }

  /// `forward` 的逆：舞台坐标 -> HTML 页面坐标。
  Offset inverse(Offset q) {
    final dx = q.dx - offset.dx;
    final dy = q.dy - offset.dy;
    final c = math.cos(rotation);
    final s = math.sin(rotation);
    final ix = (dx * c + dy * s) / scale;
    final iy = (-dx * s + dy * c) / scale;
    return Offset(ix, iy);
  }

  RenderConfig copy() => RenderConfig(
        html: html,
        displayW: displayW,
        displayH: displayH,
        outputW: outputW,
        outputH: outputH,
        offset: offset,
        scale: scale,
        rotation: rotation,
      )..lockAspect = lockAspect;
}

/// 简化变换增量（用于识别器回调）。
class TransformDelta {
  const TransformDelta({required this.offset, required this.scale, required this.rotation});
  final Offset offset;
  final double scale;
  final double rotation;
}