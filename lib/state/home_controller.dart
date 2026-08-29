import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../models/render_config.dart';

/// 底部三功能：搜索（镜头操作）、工具箱（参数）、拍摄。
enum Mode { search, tool, shoot }

/// 导入的一页 HTML。
class HtmlPage {
  HtmlPage({
    required this.name,
    required this.path,
    required this.htmlBytes,
  });

  final String name;
  final String path;
  final Uint8List htmlBytes;
}

/// 相机：把「渲染世界」投影到手机屏幕。
class Camera {
  Camera({this.position = Offset.zero, this.scale = 1.0, this.rotation = 0.0});

  /// 相机中心在“世界坐标”中的位置。
  Offset position;

  /// 缩放。
  double scale;

  /// 旋转（弧度）。
  double rotation;

  Camera copyWith({Offset? position, double? scale, double? rotation}) =>
      Camera(
        position: position ?? this.position,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
      );

  /// 世界 -> 屏幕 的变换矩阵。
  /// 让 position 落在屏幕中心，并施加上 scale 与 rotation。
  Matrix4 worldToScreen(Size screenSize) {
    final center = Offset(screenSize.width / 2, screenSize.height / 2);
    return Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..rotateZ(rotation)
      ..scaleByDouble(scale, scale, scale, 1)
      ..translateByDouble(-position.dx, -position.dy, 0, 1);
  }
}

/// 全局状态。
class HomeController extends ChangeNotifier {
  HomeController();

  Mode mode = Mode.search;
  Camera camera = Camera();
  RenderConfig config = RenderConfig();

  /// 导入的 HTML 列表。
  final List<HtmlPage> htmlPages = [];

  /// 当前选中的 HTML 下标（-1 表示空）。
  int selectedHtml = -1;

  /// 工具箱面板是否展开。
  bool toolBoxOpen = false;

  /// 拍摄配置。
  double shootSeconds = 6;
  int shootFps = 30;

  /// 是否正在取景 / 拍摄。
  bool isRecording = false;

  /// 当前拍摄进度（0.0 ~ 1.0）。
  double recordProgress = 0.0;

  bool get hasHtml => selectedHtml >= 0 && selectedHtml < htmlPages.length;
  HtmlPage? get currentHtml =>
      hasHtml ? htmlPages[selectedHtml] : null;

  void setMode(Mode m) {
    mode = m;
    // 离开工具模式时收起工具箱
    if (m != Mode.tool) toolBoxOpen = false;
    notifyListeners();
  }

  void toggleToolBox() {
    toolBoxOpen = !toolBoxOpen;
    notifyListeners();
  }

  void setToolBox(bool open) {
    if (toolBoxOpen == open) return;
    toolBoxOpen = open;
    notifyListeners();
  }

  void updateCamera(Camera c) {
    camera = c;
    notifyListeners();
  }

  void updateConfig(RenderConfig cfg) {
    config = cfg;
    notifyListeners();
  }

  void addHtml(HtmlPage page) {
    htmlPages.add(page);
    selectedHtml = htmlPages.length - 1;
    notifyListeners();
  }

  void selectHtml(int index) {
    selectedHtml = index;
    notifyListeners();
  }

  void deleteHtml(int index) {
    if (index < 0 || index >= htmlPages.length) return;
    htmlPages.removeAt(index);
    if (selectedHtml == index) {
      selectedHtml = htmlPages.isEmpty ? -1 : 0;
    }
    notifyListeners();
  }

  void setRecording(bool v) {
    isRecording = v;
    if (!v) recordProgress = 0;
    notifyListeners();
  }

  void setRecordProgress(double p) {
    recordProgress = p;
    notifyListeners();
  }

  void setShootSeconds(double v) {
    shootSeconds = v.clamp(1.0, 30.0).toDouble();
    notifyListeners();
  }

  void setShootFps(int v) {
    shootFps = v.clamp(5, 60).toInt();
    notifyListeners();
  }
}