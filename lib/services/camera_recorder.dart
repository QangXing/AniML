import 'package:flutter_screen_recording/flutter_screen_recording.dart';

import '../controllers/project_controller.dart';

/// 摄像机录制：基于 flutter_screen_recording 封装。
///
/// 说明：flutter_screen_recording 录制的是整个屏幕。AniML 会根据渲染区在
/// 屏幕中的位置进行裁剪对齐，保证「只拍摄渲染区内的内容」这一语义在屏幕上
/// 被裁剪为渲染区矩形区域。
class CameraRecorder {
  CameraRecorder._();

  static bool _recording = false;
  static bool get isRecording => _recording;
  static String _currentName = 'animl_${DateTime.now().millisecondsSinceEpoch}';

  /// 开始录制。需要在进入摄像机模式并复位视图后调用。
  static Future<bool> start(ProjectController c) async {
    if (_recording) return false;
    _currentName = 'animl_${DateTime.now().millisecondsSinceEpoch}';
    try {
      await FlutterScreenRecording.startRecordScreen(_currentName);
      _recording = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 停止录制并返回保存路径。
  static Future<String?> stop() async {
    if (!_recording) return null;
    _recording = false;
    final path = await FlutterScreenRecording.stopRecordScreen();
    return path;
  }
}