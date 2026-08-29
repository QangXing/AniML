import 'dart:ui';

/// 三种工作模式，对应左下角三个按钮：搜索 / 工具箱 / 拍摄。
enum Mode { search, tool, shoot }

/// 渲染区长宽与像素配置。
class RenderConfig {
  RenderConfig({
    this.pixelWidth = 1080,
    this.pixelHeight = 1920,
    this.pixelScale = 1.0,
    this.background = const Color(0xFFFAFAFC),
  });

  /// 渲染区「真实」像素宽（非屏幕像素）。
  int pixelWidth;

  /// 渲染区「真实」像素高（非屏幕像素）。
  int pixelHeight;

  /// 像素比：每个渲染像素在屏幕上占用多少逻辑像素（1:1 为 1.0）。
  /// 最终屏幕显示尺寸 = pixelWidth * pixelScale。
  double pixelScale;

  /// 渲染背景色（渲染区与背景之间）。
  Color background;

  double get displayWidth => pixelWidth * pixelScale;
  double get displayHeight => pixelHeight * pixelScale;
  double get aspect => pixelWidth / pixelHeight;
}