import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../state/home_controller.dart';

/// 导入本地 HTML 文件到应用文档目录，供 WebView 加载。
class HtmlImportService {
  HtmlImportService._();
  static final HtmlImportService instance = HtmlImportService._();

  /// 是否需要把字节复制到本地；为后续 WebView 稳定加载做副本。
  Future<HtmlPage?> pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['html', 'htm'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final f = result.files.single;
    final String name = f.name;
    final Uint8List bytes = f.bytes ?? (await File(f.path!).readAsBytes());

    Directory dir = await getApplicationDocumentsDirectory();
    final sub = Directory('${dir.path}/html');
    if (!await sub.exists()) await sub.create(recursive: true);
    final safeName = name.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final target = File('${sub.path}/${DateTime.now().millisecondsSinceEpoch}_$safeName');
    await target.writeAsBytes(bytes, flush: true);

    return HtmlPage(name: name, path: target.path, htmlBytes: bytes);
  }
}