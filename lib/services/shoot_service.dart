import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';

import '../state/home_controller.dart';
import 'render_engine.dart';
import 'video_encoder.dart';

/// 拍摄服务：定时抓取渲染区实时像素，攒帧后交给 [VideoEncoder] 合成 mp4。
class ShootService {
  ShootService(this._controller, this._engine);

  final HomeController _controller;
  final RenderEngine _engine;
  final VideoEncoder _encoder = VideoEncoder.instance;

  Timer? _timer;
  final List<Uint8List> _frames = [];

  bool get isRunning => _timer != null;

  /// 启动拍摄。完成后回调 [onDone(路径)]，失败回调 [onError]。
  Future<void> start({
    required double seconds,
    required int fps,
    required int width,
    required int height,
    required void Function(String path) onDone,
    required void Function(String error) onError,
  }) async {
    if (_timer != null) return;
    _frames.clear();
    _controller.setRecording(true);

    const bg = '#ffffff';
    final total = (seconds.abs() * fps).round();
    if (total <= 0) {
      onError('拍摄时长或帧率无效');
      _controller.setRecording(false);
      return;
    }
    final stepMs = ((1000 / fps)).round().clamp(1, 10000);
    final interval = Duration(milliseconds: stepMs);
    var index = 0;

    _timer = Timer.periodic(interval, (t) async {
      final png = await _engine.capture(width, height, background: bg);
      if (png != null) _frames.add(png);
      index++;
      _controller.setRecordProgress(index / total);

      if (index >= total) {
        t.cancel();
        _timer = null;
        _controller.setRecording(false);
        await _finish(width, height, fps, onDone, onError);
      }
    });
  }

  Future<void> _finish(
    int w,
    int h,
    int fps,
    void Function(String path) onDone,
    void Function(String error) onError,
  ) async {
    if (_frames.isEmpty) {
      onError('没有抓到任何帧');
      return;
    }
    try {
      final out =
          await _encoder.encodeFramesToMp4(frames: _frames, width: w, height: h, fps: fps);
      onDone(out);
    } catch (e) {
      onError('编码失败：$e');
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _controller.setRecording(false);
    _frames.clear();
  }

  Future<void> share(String path) async {
    await Share.shareXFiles([XFile(path)]);
  }
}