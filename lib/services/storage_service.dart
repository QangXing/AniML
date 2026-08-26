import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../controllers/project_controller.dart';
import '../models/project_config.dart';

/// 项目保存 / 加载 / 导出。
class StorageService {
  StorageService._();

  /// 项目根目录（应用沙箱内）。
  static Future<Directory> projectsRoot() async {
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(dir.path, 'animl_projects'));
    if (!root.existsSync()) root.createSync(recursive: true);
    return root;
  }

  /// 保存项目为 .animl_project（目录）。
  static Future<Directory> saveProject(ProjectController c) async {
    final root = await projectsRoot();
    final safe = _sanitize(c.name.isEmpty ? '未命名项目' : c.name);
    var dir = Directory(p.join(root.path, '$safe.animl'));
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);

    // 层独立导出到 layers/
    final layersDir = Directory(p.join(dir.path, 'layers'));
    layersDir.createSync(recursive: true);
    for (var i = 0; i < c.layers.length; i++) {
      final l = c.layers[i];
      final sub = Directory(p.join(layersDir.path, 'layer_${i.toString().padLeft(4, '0')}'));
      sub.createSync(recursive: true);
      File(p.join(sub.path, 'index.html')).writeAsStringSync(l.source);
    }

    // project.json
    final json = ProjectConfig(
      name: c.name != '' ? c.name : _metaName,
      version: '0.1.0',
      canvas: c.canvas,
      viewport: c.viewport,
      layers: c.layers,
      timelineDuration: c.timelineDuration,
      timelineClips: c.clips
          .map((cl) => {'id': cl.id, 'layerId': cl.layerId, 'start': cl.startMs, 'end': cl.endMs})
          .toList(),
      camera: c.camera,
    ).toJson();
    json['name'] = c.name;
    File(p.join(dir.path, 'project.json'))
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
    return dir;
  }

  static const _metaName = '未命名项目';

  /// 当前打开项目的显示名（供 UI 展示）。
  static String get displayName => _metaName;

  static String _sanitize(String s) => s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}