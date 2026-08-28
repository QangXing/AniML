import 'package:flutter/material.dart';

/// 渲染区（画布）配置。
class CanvasConfig {
  CanvasConfig({
    required this.width,
    required this.height,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.showGrid = true,
    this.gridSize = 50.0,
  });

  double width;
  double height;
  Color backgroundColor;
  bool showGrid;
  double gridSize;

  /// 设置分辨率（可选按比例）。
  void setSize(double w, double h, {bool keepAspect = false}) {
    if (keepAspect) {
      final ratio = height / width;
      height = w * ratio;
    }
    width = w;
    height = h;
  }

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'backgroundColor': backgroundColor.value,
        'showGrid': showGrid,
        'gridSize': gridSize,
      };

  factory CanvasConfig.fromJson(Map<String, dynamic> json) => CanvasConfig(
        width: (json['width'] ?? 1920).toDouble(),
        height: (json['height'] ?? 1080).toDouble(),
        backgroundColor: Color((json['backgroundColor'] ?? 0xFFFFFFFF) as int),
        showGrid: (json['showGrid'] ?? true) as bool,
        gridSize: (json['gridSize'] ?? 50).toDouble(),
      );
}