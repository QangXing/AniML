import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import '../models/editor_mode.dart';
import '../models/render_config.dart';

/// 全局状态控制器：持有渲染配置、当前模式，并把页面变换暴露给手势识别器。
class RenderController extends ChangeNotifier {
  final RenderConfig config = RenderConfig();

  /// 当前工作模式（搜索 / 更改 / 拍摄）。
  EditorMode mode = EditorMode.search;

  /// 是否正在录制（拍摄中）。
  bool recording = false;

  // ---- HTML ----
  void setHtml(String html) {
    config.html = html;
    notifyListeners();
  }

  // ---- 模式 ----
  void setMode(EditorMode m) {
    mode = m;
    notifyListeners();
  }

  // ---- 渲染区尺寸 ----
  /// 按逻辑宽 / 高设置渲染区（保持长宽比时可联动更新）。
  void setDisplaySize(double w, double h) {
    if (config.lockAspect) {
      // 以较“主动”的一侧为准：这里约定宽优先。
      config.displayW = w;
      config.displayH = w / config.aspect;
    } else {
      config.displayW = w;
      config.displayH = h;
    }
    notifyListeners();
  }

  /// 只有锁比例时按比例重新设定高度会用到。
  void setDisplayWidth(double w) => setDisplaySize(w, config.displayH);
  void setDisplayHeight(double h) {
    if (config.lockAspect) {
      config.displayH = h;
      config.displayW = h * config.aspect;
    } else {
      config.displayH = h;
    }
    notifyListeners();
  }

  void setOutputSize(int w, int h) {
    config.outputW = w;
    config.outputH = h;
    config.aspectIfChanged(); // 同步渲染区比例
    notifyListeners();
  }

  /// 应用比例预设（修改渲染区比例同时按比例调整像素）。
  void applyAspectPreset(int aw, int ah) {
    final oldAspect = config.aspect;
    config.displayW = config.displayH * (aw / ah);
    if ((oldAspect - aw / ah).abs() > 1e-6) {
      // 只调显示比例，像素稍后由用户确认
    }
    notifyListeners();
  }

  void setLockAspect(bool v) {
    config.lockAspect = v;
    notifyListeners();
  }

  // ---- 页面变换 ----
  void setTransform(TransformDelta d) {
    config.offset = d.offset;
    config.scale = d.scale.clamp(0.2, 6.0).toDouble();
    config.rotation = d.rotation;
    notifyListeners();
  }

  void setRotation(double radians) {
    config.rotation = radians;
    notifyListeners();
  }

  void resetTransform() {
    config.offset = Offset.zero;
    config.scale = 1.0;
    config.rotation = 0.0;
    notifyListeners();
  }

  // ---- 录制状态 ----
  void setRecording(bool v) {
    recording = v;
    notifyListeners();
  }
}

extension on RenderConfig {
  void aspectIfChanged() {
    // 保持渲染区高不变、按输出比例更新宽
    displayW = displayH * (outputW / outputH);
  }
}