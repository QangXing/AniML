import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../state/home_controller.dart';
import 'render_engine.dart';
import 'video_encoder.dart';

/// 拍摄服务：定时抓取渲染区实时像素，逐帧写入磁盘后交给 [VideoEncoder] 合成 mp4。
/// 采用「串行抓帧 + 边拍边写盘」，避免帧堆积导致内存溢出闪退。
class ShootService {
  ShootService(this._controller, this._engine);

  final HomeController _controller;
  final RenderEngine _engine;
  final VideoEncoder _encoder = VideoEncoder.instance;

  bool _running = false;
  bool _cancelled = false;
  Directory? _framesDir;

  bool get isRunning => _running;

  /// 启动拍摄。完成后回调 [onDone(路径)]，失败回调 [onError]。
  Future<void> start({
    required double seconds,
    required int fps,
    required int width,
    required int height,
    required void Function(String path) onDone,
    required void Function(String error) onError,
  }) async {
    if (_running) return;
    _cancelled = false;
    _controller.setRecording(true);

    final total = (seconds.abs() * fps).round();
    if (total <= 0) {
      onError('拍摄时长或帧率无效');
      _controller.setRecording(false);
      return;
    }

    // 帧目录随拍摄单独创建，避免与旧帧残留冲突。
    _framesDir = Directory(
        '${(await getTemporaryDirectory()).path}/frames_${DateTime.now().millisecondsSinceEpoch}');
    await _framesDir!.create(recursive: true);

    const bg = '#ffffff';
    final interval =
        Duration(milliseconds: (1000 / fps).round().clamp(1, 10000));

    _running = true;
    var index = 0;
    var written = 0;
    // 串行抓帧：等上一帧完成再抓下一帧，杜绝 Timer 重叠导致的帧数爆炸与内存峰值。
    while (_running && index < total) {
      final png = await _engine.capture(width, height, background: bg);
      if (_running && png != null) {
        await File(
                '${_framesDir!.path}/frame_${written.toString().padLeft(4, '0')}.png')
            .writeAsBytes(png);
        written++;
      }
      index++;
      _controller.setRecordProgress(index / total);
      if (_running && index < total) {
        await Future.delayed(interval);
      }
    }

    _running = false;
    _controller.setRecording(false);
    if (_cancelled) {
      _cleanupFrames();
      return;
    }
    if (written <= 0) {
      onError('没有抓到任何帧');
      _cleanupFrames();
      return;
    }
    try {
      final out = await _encoder.encodeFramesFromDir(
        framesDir: _framesDir!,
        count: written,
        width: width,
        height: height,
        fps: fps,
      );
      onDone(out);
    } catch (e) {
      onError('编码失败：$e');
    } finally {
      _cleanupFrames();
    }
  }

  void _cleanupFrames() {
    try {
      _framesDir?.deleteSync(recursive: true);
    } catch (_) {}
    _framesDir = null;
  }

  /// 停止拍摄（仅抓帧阶段可打断；编码阶段不可中断）。
  void stop() {
    if (!_running) return;
    _cancelled = true;
    _running = false;
    _controller.setRecording(false);
    _cleanupFrames();
  }

  Future<void> share(String path) async {
    await Share.shareXFiles([XFile(path)]);
  }
}
