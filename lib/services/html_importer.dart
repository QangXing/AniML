import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../controllers/project_controller.dart';

/// 从本地导入 HTML/文件夹/zip，并注入为新的层。
class HtmlImporter {
  HtmlImporter._();

  /// 打开文件选择器，导入 HTML 为新层。返回是否成功。
  static Future<bool> import(ProjectController c) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['html', 'htm', 'zip'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return false;
    final file = result.files.single;
    final name = file.name;

    if (name.endsWith('.zip')) {
      return _importZip(c, file.path);
    }

    if (file.path == null || !File(file.path!).existsSync()) return false;
    final source = File(file.path!).readAsStringSync();
    final dir = p.dirname(file.path!);
    c.addLayer(name: p.basenameWithoutExtension(name), source: source, assetPath: dir);
    return true;
  }

  /// 从项目内 layers 目录恢复层（供项目加载使用）。
  static void fromDirectory(ProjectController c, String name, Directory layerDir) {
    final indexFile = File(p.join(layerDir.path, 'index.html'));
    if (!indexFile.existsSync()) return;
    final source = indexFile.readAsStringSync();
    c.addLayer(name: name, source: source, assetPath: layerDir.path);
  }

  static Future<bool> _importZip(ProjectController c, String? zipPath) async {
    // 简单提示：zip 导入需要先用 Archive 解压，这里做占位实现。
    if (zipPath == null) return false;
    // TODO(animl): 使用 archive 包解压并解析 index.html
    return false;
  }
}