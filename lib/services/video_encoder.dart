import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';

/// 把按时间顺序采集的 JPG/PNG 帧序列编码为 MP4。
class VideoEncoder {
  /// 将 [frames]（帧字节，JPG/PNG）按 [fps] 合成为 [outputPath] 处的 MP4。
  ///
  /// 实现：先把帧依次写入临时目录，再用 FFmpeg `-framerate` 拼接。
  /// 返回输出文件路径；失败时抛出异常。
  static Future<File> encodeFrames({
    required List<Uint8List> frames,
    required String outputPath,
    required double fps,
    String? progressCallback,
  }) async {
    if (frames.isEmpty) {
      throw Exception('没有可编码的帧');
    }

    // 1. 写帧到临时目录
    final tempDir = await Directory(outputPath).parent.createTemp('frames_');
    final pattern = '${tempDir.path}/frame_%05d.jpg';
    for (var i = 0; i < frames.length; i++) {
      File('${tempDir.path}/frame_${_pad(i + 1)}.jpg')
          .writeAsBytesSync(frames[i], flush: true);
    }

    try {
      // 2. FFmpeg 合成
      final cmd =
          '-y -framerate ${fps.toStringAsFixed(2)} -i "$pattern" '
          '-c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p '
          '-movflags +faststart -an "$outputPath"';
      final session = await FFmpegKit.executeAsync(cmd);

      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) {
        return File(outputPath);
      } else if (ReturnCode.isCancel(rc)) {
        throw Exception('编码已取消');
      } else {
        final logs = await session.getAllLogsAsString();
        throw Exception('FFmpeg 编码失败：\n$logs');
      }
    } finally {
      // 3. 清理临时帧
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    }
  }

  static String _pad(int n) => n.toString().padLeft(5, '0');
}