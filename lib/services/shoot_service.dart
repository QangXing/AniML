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
    // 帧间仅需留出浏览器绘制“seek 后画面”的时间即可，不再按帧率等待，
    // 虚拟时钟已决定每帧内容，无需真实时间对齐；范围 16~40ms 足够一次合成。
    final perFrameMs = (1000 / fps).round();
    final settleMs = perFrameMs < 16 ? 16 : (perFrameMs > 40 ? 40 : perFrameMs);
    final settle = Duration(milliseconds: settleMs);

    _running = true;
    // 进入录制模式：暂停页面动画并用虚拟时钟逐帧驱动。
    // 每一帧先把动画拨到精确时间再抓，避免“抓帧慢 → 动画已跑远 → 视频跳变”。
    await _engine.beginRecord(fps);
    // 等 t=0 的画面绘制完成再抓第一帧。
    await Future.delayed(settle);

    var index = 0;
    var written = 0;
    var frameW = width;
    var frameH = height;
    // 串行抓帧：等上一帧完成再抓下一帧，杜绝 Timer 重叠导致的帧数爆炸与内存峰值。
    // 每帧以裸 RGB24 写盘（跳过 PNG 编码），ffmpeg 直接读裸帧，大幅提速。
    while (_running && index < total) {
      final frame = await _engine.captureRaw(width, height, background: bg);
      if (_running && frame != null) {
        if (written == 0) {
          // 以首帧实际尺寸为准：toImage 的 ceil 舍入在非整数缩放时可能偏差 1px，
          // 而裸帧解码要求尺寸完全精确，否则整段解析错乱。
          frameW = frame.width;
          frameH = frame.height;
        }
        await File(
                '${_framesDir!.path}/frame_${written.toString().padLeft(4, '0')}.rgba')
            .writeAsBytes(frame.rgb);
        written++;
      }
      index++;
      _controller.setRecordProgress(index / total);
      if (_running && index < total) {
        // 拨到下一帧对应的动画时间，并留出浏览器绘制该帧的时间。
        await _engine.seekRecord(index / fps);
        await Future.delayed(settle);
      }
    }
    // 无论成功/取消都恢复页面动画。
    await _engine.endRecord();
    // 拍摄结束后刷新一次预览帧（PNG），用于渲染区背景的淡化底图。
    await _engine.capture(width, height, background: bg);

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
        frameWidth: frameW,
        frameHeight: frameH,
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
