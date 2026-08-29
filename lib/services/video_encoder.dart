import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

/// 把磁盘上一组 PNG 帧（frame_0000.png …）编码成 mp4。
/// 帧由拍摄服务边拍边写入，编码时逐帧读盘，避免整批驻留内存。
class VideoEncoder {
  VideoEncoder._();
  static final VideoEncoder instance = VideoEncoder._();

  /// [framesDir] 内应已存在按序号命名的 frame_%04d.png，[count] 为帧数。
  /// 返回输出文件路径，失败抛异常。
  Future<String> encodeFramesFromDir({
    required Directory framesDir,
    required int count,
    required int width,
    required int height,
    required int fps,
  }) async {
    if (count <= 0) {
      throw StateError('没有可用的帧');
    }
    final dirPath = framesDir.path;
    final out =
        '${(await getTemporaryDirectory()).path}/output_${DateTime.now().millisecondsSinceEpoch}.mp4';
    // 帧序拼装，编码为 yuv420p，保证大多数播放器可播。
    final command =
        '-y -framerate $fps -i "$dirPath/frame_%04d.png" '
        '-vf "scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2:color=white,fps=$fps,format=yuv420p" '
        '-c:v libx264 -pix_fmt yuv420p -movflags +faststart "$out"';

    final session = await FFmpegKit.execute(command);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) return out;
    throw StateError('ffmpeg 编码失败，返回码 $rc');
  }
}
