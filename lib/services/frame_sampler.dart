import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

/// 从整张 WebView 截图里，按当前页面变换，抓取“渲染区”像素并重采样到输出分辨率。
///
/// 基本原理：
///  - WebView 截图是整块画布（几何尺寸 = `stageSize`，实际像素尺寸 = `stageSize * dpr`）；
///  - 渲染区是叠加在画布上的固定矩形 `renderRect`（逻辑坐标，位于舞台内）；
///  - 页面变换把 HTML 内容在画布内平移/缩放/旋转；
///  - 对渲染区内每个输出像素，用 `inverse()` 求出其对应的原始画布坐标并做双线性采样。
class FrameSampler {
  /// 采样一个渲染区帧。
  ///
  /// [screenshotBytes] WebView `takeScreenshot()` 返回的原始截图字节，
  /// [stageSize] WebView 在舞台上占用的逻辑尺寸，
  /// [renderRect] 渲染区矩形的逻辑坐标（舞台坐标系内，中心即窗口位置），
  /// [offset]/[scale]/[rotation] 当前页面变换（与渲染一致），
  /// [outputWidth]/[outputHeight] 输出分辨率。
  static Uint8List? sample(
    Uint8List screenshotBytes, {
    required Size stageSize,
    required Rect renderRect,
    required Offset offset,
    required double scale,
    required double rotation,
    required int outputWidth,
    required int outputHeight,
  }) {
    if (outputWidth <= 0 || outputHeight <= 0) return null;
    if (stageSize.width <= 0 || scale <= 0) return null;

    final src = img.decodeImage(screenshotBytes);
    if (src == null) return null;

    final srcW = src.width;
    final srcH = src.height;
    if (srcW == 0 || srcH == 0) return null;

    // 舞台逻辑单位 -> 截图像素 的比例（宽高应一致）
    final r = srcW / stageSize.width;

    final out = img.Image(width: outputWidth, height: outputHeight, numChannels: 3);

    final cosR = math.cos(-rotation);
    final sinR = math.sin(-rotation);

    for (var y = 0; y < outputHeight; y++) {
      for (var x = 0; x < outputWidth; x++) {
        final fx = (x + 0.5) / outputWidth;
        final fy = (y + 0.5) / outputHeight;

        // 渲染区内的舞台逻辑坐标
        final qx = renderRect.left + fx * renderRect.width;
        final qy = renderRect.top + fy * renderRect.height;

        // 逆变换求原始画布（HTML）坐标
        final tx = qx - offset.dx;
        final ty = qy - offset.dy;
        final px = (cosR * tx - sinR * ty) / scale;
        final py = (sinR * tx + cosR * ty) / scale;

        // 画布坐标 -> 截图像素（画布原点=（0,0）= 截图左上角）
        final sxC = px * r;
        final syC = py * r;

        // 双线性采样
        final color = _bilinearPixel(src, srcW, srcH, sxC, syC);
        out.setPixelRgb(x, y, color[0], color[1], color[2]);
      }
    }

    return img.encodeJpg(out, quality: 92);
  }

  /// 简单双线性采样。出界返回白色（模拟渲染区外留白）。
  static List<int> _bilinearPixel(
    img.Image src,
    int w,
    int h,
    double x,
    double y,
  ) {
    final x0 = x.floor();
    final y0 = y.floor();
    if (x0 < 0 || y0 < 0 || x0 >= w - 1 || y0 >= h - 1) {
      return [247, 249, 253];
    }
    final fx = x - x0;
    final fy = y - y0;

    List<int> rgb(int px, int py) {
      final c = src.getPixel(px, py);
      return [c.r.toInt(), c.g.toInt(), c.b.toInt()];
    }

    List<int> lerp(List<int> a, List<int> b, double t) => [
          (a[0] + (b[0] - a[0]) * t).round().clamp(0, 255).toInt(),
          (a[1] + (b[1] - a[1]) * t).round().clamp(0, 255).toInt(),
          (a[2] + (b[2] - a[2]) * t).round().clamp(0, 255).toInt(),
        ];

    final p00 = rgb(x0.toInt(), y0.toInt());
    final p10 = rgb(x0.toInt() + 1, y0.toInt());
    final p01 = rgb(x0.toInt(), y0.toInt() + 1);
    final p11 = rgb(x0.toInt() + 1, y0.toInt() + 1);

    final top = lerp(p00, p10, fx);
    final bottom = lerp(p01, p11, fx);
    return lerp(top, bottom, fy);
  }
}