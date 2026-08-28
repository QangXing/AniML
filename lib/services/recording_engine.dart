import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'video_encoder.dart';

/// 帧生产者：抓取渲染区内实时像素，返回一张 JPG 帧；无法抓取时返回 null。
typedef FrameProducer = Future<Uint8List?> Function();

/// 录制引擎：按固定帧率周期性抓取渲染区像素，采集完毕后合成 MP4。
class RecordingEngine {
  RecordingEngine({required this.producer, this.fps = 24});

  /// 负责抓取单帧（渲染区实时像素 → JPG 字节）。
  final FrameProducer producer;

  /// 拍摄帧率。
  final double fps;

  Timer? _timer;
  final List<Uint8List> _frames = [];
  bool _done = false;

  /// 是否正在录制。
  bool get isRecording => _timer != null && !_done;

  /// 当前已采帧数。
  int get capturedFrames => _frames.length;

  /// 录制期间的进度回调（[frame] 当前帧号，[total] 总帧数）。
  void Function(int frame, int total)? onProgress;

  /// 录制完成的回调：[0]=输出文件，[1]=错误信息（成功时为空）。
  void Function(String? path, String? error)? onComplete;

  /// 开始录制，持续 [durationSeconds] 秒。
  Future<void> start(int durationSeconds) async {
    await stop();
    _frames.clear();
    _done = false;
    final total = ((durationSeconds * fps).round()).clamp(1, 1 << 20).toInt();

    // 预启动一次，确保 WebView 可用
    final first = await producer();
    if (first != null) _frames.add(first);
    onProgress?.call(1, total);

    final interval = Duration(milliseconds: (1000 / fps).round());
    _timer = Timer.periodic(interval, (_) async {
      if (_done) return;
      final frame = await producer();
      if (frame != null) _frames.add(frame);
      if (_frames.length >= total) {
        await _finish(true);
      } else {
        onProgress?.call(_frames.length, total);
      }
    });
  }

  /// 停止录制（正常结束为 [finish=true]，此时会立即合成；取消则丢弃）。
  Future<void> stop({bool finish = false}) async {
    if (finish) {
      await _finish(true);
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _finish(bool encode) async {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    _timer = null;

    if (!encode || _frames.isEmpty) {
      onComplete?.call(null, _frames.isEmpty ? '未采集到帧' : null);
      _frames.clear();
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final outPath = p.join(dir.path, 'render_$stamp.mp4');
      final file = await VideoEncoder.encodeFrames(
        frames: _frames,
        outputPath: outPath,
        fps: fps,
      );
      _frames.clear();
      // 存入系统相册/公共媒体库，方便用户在系统相册中直接查看、导出、分享。
      final handled = await _exportToGallery(file.path);
      onComplete?.call(handled, null);
    } catch (e) {
      _frames.clear();
      onComplete?.call(null, e.toString());
    }
  }

  /// 把 MP4 存入系统相册（专辑 AniML），成功后删除私有临时副本，返回展示用路径。
  Future<String> _exportToGallery(String localPath) async {
    try {
      await Gal.requestAccess();
      await Gal.putVideo(localPath, album: 'AniML');
      final f = File(localPath);
      if (await f.exists()) await f.delete();
      return '相册（AniML）/ render_${DateTime.now().millisecondsSinceEpoch}.mp4';
    } catch (_) {
      // 保存相册失败时保留本地私有副本，仍可返回原路径。
      return localPath;
    }
  }

  /// 取消录制，丢弃已采集帧。
  Future<void> cancel() => stop(finish: false);
}