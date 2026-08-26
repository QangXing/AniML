import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/anime_layer.dart';
import '../models/project_config.dart';
import '../services/html_compiler.dart';
import '../utils/constants.dart';

/// AniML 的 master controller：维护渲染区、层、时间轴、模式与播放状态。
/// 使用 ChangeNotifier + notifyListeners 触发 UI 重建。
class ProjectController extends ChangeNotifier {
  ProjectController();

  static const _uuid = Uuid();
  Timer? _playTimer;

  // ---------- 状态字段（可被 UI 直接读取）
  String name = '未命名项目';
  CanvasConfig canvas = CanvasConfig(width: 1920, height: 1080);
  ViewportConfig viewport = ViewportConfig();
  CameraConfig camera = CameraConfig();
  List<AniLayer> layers = <AniLayer>[];
  List<ClipRef> clips = <ClipRef>[];
  Duration timelineDuration = const Duration(seconds: 10);

  int mode = AppMode.search;
  Duration playhead = Duration.zero;
  bool playing = false;
  bool previewLoop = true;

  bool showGrid = true;
  bool showAxis = true;
  String? activeLayerId;

  void rename(String newName) {
    name = newName.trim().isEmpty ? '未命名项目' : newName.trim();
    notifyListeners();
  }

  // ------------------------------------------------------------------ 模式
  void setMode(int value) {
    if (value == mode) return;
    if (value == AppMode.camera) {
      viewport.reset(); // 摄像机模式强制 1:1
      pause();
    }
    mode = value;
    notifyListeners();
  }

  // ------------------------------------------------------------------ 渲染区
  void setCanvasSize(double w, double h, {bool keepAspect = false}) {
    if (w <= 0 || h <= 0) return;
    canvas.setSize(w, h, keepAspect: keepAspect);
    notifyListeners();
  }

  void setCanvasBackground(Color c) {
    canvas.backgroundColor = c;
    notifyListeners();
  }

  void setGridVisible(bool v) {
    canvas.showGrid = v;
    showGrid = v;
    notifyListeners();
  }

  // ------------------------------------------------------------------ 视口
  void updateViewport({double? scale, double? offsetX, double? offsetY, double? rotation}) {
    scale = scale?.clamp(AppConstants.minViewportScale, AppConstants.maxViewportScale);
    if (scale != null) viewport.scale = scale;
    if (offsetX != null) viewport.offsetX = offsetX;
    if (offsetY != null) viewport.offsetY = offsetY;
    if (rotation != null) viewport.rotation = rotation;
    notifyListeners();
  }

  void resetViewport() {
    viewport.reset();
    notifyListeners();
  }

  // ------------------------------------------------------------------ 层
  AniLayer addLayer({
    required String name,
    String source = _emptyHtml,
    String? assetPath,
  }) {
    final layer = AniLayer(
      id: _uuid.v4(),
      name: name,
      index: layers.length,
      source: source,
      assetPath: assetPath,
    );
    layers.add(layer);
    clips.add(ClipRef(
      _uuid.v4(),
      layer.id,
      0,
      AppConstants.defaultClipDuration.inMilliseconds,
    ));
    _sortLayers();
    notifyListeners();
    return layer;
  }

  void removeLayer(String layerId) {
    layers.removeWhere((l) => l.id == layerId);
    clips.removeWhere((c) => c.layerId == layerId);
    if (activeLayerId == layerId) activeLayerId = null;
    _sortLayers();
    notifyListeners();
  }

  void reorderLayer(String layerId, int targetIndex) {
    final from = layers.indexWhere((l) => l.id == layerId);
    if (from < 0) return;
    final layer = layers.removeAt(from);
    targetIndex = targetIndex.clamp(0, layers.length);
    layers.insert(targetIndex, layer);
    _sortLayers();
    notifyListeners();
  }

  void setLayerFlags(String layerId, {bool? visible, bool? locked, double? opacity}) {
    final idx = layers.indexWhere((l) => l.id == layerId);
    if (idx < 0) return;
    layers[idx].visible = visible ?? layers[idx].visible;
    layers[idx].locked = locked ?? layers[idx].locked;
    layers[idx].opacity = opacity ?? layers[idx].opacity;
    notifyListeners();
  }

  void setActiveLayer(String? layerId) {
    activeLayerId = layerId;
    notifyListeners();
  }

  void updateLayerSource(String layerId, String source) {
    final idx = layers.indexWhere((l) => l.id == layerId);
    if (idx < 0) return;
    layers[idx].source = source;
    notifyListeners();
  }

  void _sortLayers() {
    layers.sort((a, b) => a.index.compareTo(b.index));
    for (var i = 0; i < layers.length; i++) {
      layers[i].index = i;
    }
  }

  // ------------------------------------------------------------------ 时间轴
  void setTimelineDuration(Duration d) {
    if (d.inMilliseconds <= 0) return;
    timelineDuration = d;
    notifyListeners();
  }

  List<ClipRef> clipsFor(String layerId) =>
      clips.where((c) => c.layerId == layerId).toList();

  bool addClip(String layerId, int startMs, int endMs) {
    if (endMs <= startMs) return false;
    for (final c in clips) {
      if (c.layerId == layerId && (startMs < c.endMs && endMs > c.startMs)) {
        return false; // 同轨道不允许重叠
      }
    }
    clips.add(ClipRef(_uuid.v4(), layerId, startMs, endMs));
    notifyListeners();
    return true;
  }

  void removeClip(String clipId) {
    clips.removeWhere((c) => c.id == clipId);
    notifyListeners();
  }

  bool moveClip(String clipId, int deltaMs) {
    final c = clips.firstWhere((x) => x.id == clipId, orElse: () => _none);
    if (identical(c, _none)) return false;
    final newStart = c.startMs + deltaMs;
    final newEnd = c.endMs + deltaMs;
    return _applyClipTime(c, newStart, newEnd);
  }

  bool resizeClip(String clipId, {int? startMs, int? endMs}) {
    final c = clips.firstWhere((x) => x.id == clipId, orElse: () => _none);
    if (identical(c, _none)) return false;
    return _applyClipTime(c, startMs ?? c.startMs, endMs ?? c.endMs);
  }

  bool _applyClipTime(ClipRef c, int newStart, int newEnd) {
    if (newEnd <= newStart) return false;
    if (newStart < 0) return false;
    for (final other in clips) {
      if (other == c) continue;
      if (other.layerId == c.layerId &&
          newStart < other.endMs &&
          newEnd > other.startMs) {
        return false; // 同轨道不允许重叠
      }
    }
    c.startMs = newStart;
    c.endMs = newEnd;
    notifyListeners();
    return true;
  }

  static final ClipRef _none = ClipRef('', '', 0, 0);

  // ------------------------------------------------------------------ 播放
  void play() {
    if (playing) return;
    playing = true;
    notifyListeners();
    _playTimer?.cancel();
    _playTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      final next = playhead + const Duration(milliseconds: 33);
      if (next.inMilliseconds >= timelineDuration.inMilliseconds) {
        if (previewLoop) {
          playhead = Duration.zero;
        } else {
          pause();
          return;
        }
      } else {
        playhead = next;
      }
      _onPlayhead();
      notifyListeners();
    });
  }

  void pause() {
    playing = false;
    _playTimer?.cancel();
    notifyListeners();
  }

  void stop() {
    playing = false;
    _playTimer?.cancel();
    playhead = Duration.zero;
    _onPlayhead();
    notifyListeners();
  }

  void seek(Duration position) {
    playhead = position < timelineDuration ? position : timelineDuration;
    _onPlayhead();
    notifyListeners();
  }

  bool isClipActiveAt(ClipRef clip, Duration t) =>
      t.inMilliseconds >= clip.startMs && t.inMilliseconds < clip.endMs;

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }

  _PlayheadHook? _hook;
  set playheadHook(_PlayheadHook? h) => _hook = h;
  void _onPlayhead() => _hook?.call(this);

  // ------------------------------------------------------------------ 摄像机
  void setCamera({String? format, int? fps, double? width, double? height}) {
    if (format != null) camera.format = format;
    if (fps != null) camera.fps = fps;
    if (width != null && width > 0) camera.width = width;
    if (height != null && height > 0) camera.height = height;
    notifyListeners();
  }

  /// 导出 HTML（本地字符串）。
  String export({
    double? width,
    double? height,
  }) {
    return HtmlCompiler.compile(this, width: width ?? canvas.width, height: height ?? canvas.height);
  }
}

typedef _PlayheadHook = void Function(ProjectController controller);

/// 条带的运行时表示。
class ClipRef {
  ClipRef(this.id, this.layerId, this.startMs, this.endMs);
  final String id;
  final String layerId;
  int startMs;
  int endMs;
}

const _emptyHtml = '<!DOCTYPE html><html><head></head><body></body></html>';

final projectProvider =
    ChangeNotifierProvider<ProjectController>((ref) => ProjectController());