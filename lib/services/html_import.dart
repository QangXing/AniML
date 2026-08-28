import 'dart:io';

import 'package:file_picker/file_picker.dart';

/// 读取用户选择的 HTML 文件内容。
class HtmlImport {
  /// 弹出文件选择器并读取一个 `.html` 文件的内容。
  ///
  /// 返回 [null] 表示用户取消了选择，或读取失败。
  static Future<String?> pickHtmlFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['html', 'htm'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }
}