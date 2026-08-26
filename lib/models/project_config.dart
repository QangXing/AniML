import 'anime_layer.dart';
import 'canvas_config.dart';

/// 摄像机录制配置。
class CameraConfig {
  CameraConfig({
    this.format = 'mp4',
    this.fps = 30,
    this.width = 1920,
    this.height = 1080,
  });

  String format; // mp4 | webm | gif
  int fps;
  double width;
  double height;

  Map<String, dynamic> toJson() => {
        'format': format,
        'fps': fps,
        'width': width,
        'height': height,
      };

  factory CameraConfig.fromJson(Map<String, dynamic> json) => CameraConfig(
        format: json['format'] as String? ?? 'mp4',
        fps: (json['fps'] ?? 30) as int,
        width: (json['width'] ?? 1920).toDouble(),
        height: (json['height'] ?? 1080).toDouble(),
      );
}

/// 视口配置（搜索模式的缩放、平移、旋转）。
class ViewportConfig {
  ViewportConfig({
    this.scale = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.rotation = 0.0,
  });

  double scale;
  double offsetX;
  double offsetY;
  double rotation; // 弧度

  void reset() {
    scale = 1.0;
    offsetX = 0.0;
    offsetY = 0.0;
    rotation = 0.0;
  }

  Map<String, dynamic> toJson() => {
        'scale': scale,
        'offsetX': offsetX,
        'offsetY': offsetY,
        'rotation': rotation,
      };

  factory ViewportConfig.fromJson(Map<String, dynamic> json) => ViewportConfig(
        scale: (json['scale'] ?? 1.0).toDouble(),
        offsetX: (json['offsetX'] ?? 0.0).toDouble(),
        offsetY: (json['offsetY'] ?? 0.0).toDouble(),
        rotation: (json['rotation'] ?? 0.0).toDouble(),
      );
}

/// 项目文件（对应 .animl_project 的 project.json）。
class ProjectConfig {
  ProjectConfig({
    required this.name,
    this.version = '0.1.0',
    required this.canvas,
    required this.viewport,
    required this.layers,
    this.timelineDuration = const Duration(seconds: 10),
    required this.timelineClips,
    required this.camera,
  });

  String name;
  String version;
  CanvasConfig canvas;
  ViewportConfig viewport;
  List<AniLayer> layers;
  Duration timelineDuration;
  List<dynamic> timelineClips; // 由 TimelineController 解析为 Clip
  CameraConfig camera;

  static ProjectConfig createDefault() => ProjectConfig(
        name: '未命名项目',
        canvas: CanvasConfig(width: 1920, height: 1080),
        viewport: ViewportConfig(),
        layers: <AniLayer>[],
        timelineDuration: const Duration(seconds: 10),
        timelineClips: <dynamic>[],
        camera: CameraConfig(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version,
        'canvas': canvas.toJson(),
        'viewport': viewport.toJson(),
        'layers': layers.map((l) => l.toJson()).toList(),
        'timelineDuration': timelineDuration.inMilliseconds,
        'timelineClips': timelineClips,
        'camera': camera.toJson(),
      };

  factory ProjectConfig.fromJson(Map<String, dynamic> json) => ProjectConfig(
        name: json['name'] as String? ?? '未命名项目',
        version: json['version'] as String? ?? '0.1.0',
        canvas: CanvasConfig.fromJson(
            json['canvas'] as Map<String, dynamic>? ?? <String, dynamic>{}),
        viewport: ViewportConfig.fromJson(
            json['viewport'] as Map<String, dynamic>? ?? <String, dynamic>{}),
        layers: (json['layers'] as List<dynamic>? ?? [])
            .map((e) => AniLayer.fromJson(e as Map<String, dynamic>))
            .toList(),
        timelineDuration:
            Duration(milliseconds: (json['timelineDuration'] ?? 10000) as int),
        timelineClips: json['timelineClips'] as List<dynamic>? ?? [],
        camera: CameraConfig.fromJson(
            json['camera'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      );
}