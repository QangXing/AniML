import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// 把一组 PNG 帧(PNG 字节)编码成 mp4。
class VideoEncoder {
  VideoEncoder._();
  static final VideoEncoder instance = VideoEncoder._();

  /// [frames] 每帧为 PNG 字节；[width]/[height] 目标像素；[fps] 帧率。
  /// 返回输出文件路径，失败抛异常。
  Future<String> encodeFramesToMp4({
    required List<Uint8List> frames,
    required int width,
    required int height,
    required int fps,
  }) async {
    if (frames.isEmpty) {
      throw StateError('没有可用的帧');
    }
    final temp = Directory('${(await getTemporaryDirectory()).path}/frames');
    if (await temp.exists()) await temp.delete(recursive: true);
    await temp.create(recursive: true);

    // 规整每帧尺寸并写盘，供 ffmpeg 按序号读取。
    for (var i = 0; i < frames.length; i++) {
      final norm = await _normalizePng(frames[i], width, height);
      final f = File('${temp.path}/frame_${i.toString().padLeft(4, '0')}.png');
      await f.writeAsBytes(norm, flush: true);
    }

    final out = '${temp.path}/output_${DateTime.now().millisecondsSinceEpoch}.mp4';
    // 帧序拼装，编码为 yuv420p，保证大多数播放器可播。
    final command =
        '-y -framerate $fps -i "${temp.path}/frame_%04d.png" '
        '-vf "scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2:color=white,fps=$fps,format=yuv420p" '
        '-c:v libx264 -pix_fmt yuv420p -movflags +faststart "$out"';

    final session = await FFmpegKit.execute(command);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) return out;
    throw StateError('ffmpeg 编码失败，返回码 $rc');
  }

  /// 把任意 PNG 解码后重绘为 [width]x[height] 的 PNG 字节。
  Future<Uint8List> _normalizePng(Uint8List bytes, int width, int height) async {
    final decoded = img.decodePng(bytes);
    if (decoded == null) return _resizeFromRaw(bytes, width, height);
    final resized = img.copyResize(
      decoded,
      width: width == 0 ? decoded.width : width,
      height: height == 0 ? decoded.height : height,
      interpolation: img.Interpolation.cubic,
    );
    return Uint8List.fromList(img.encodePng(resized));
  }

  Uint8List _resizeFromRaw(Uint8List bytes, int w, int h) {
    var plain = bytes;
    final dec = img.decodeImage(plain);
    if (dec != null) {
      final r = img.copyResize(dec,
          width: w, height: h, interpolation: img.Interpolation.cubic);
      return Uint8List.fromList(img.encodePng(r));
    }
    return plain;
  }
}