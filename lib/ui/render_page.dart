import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../controllers/project_controller.dart';
import '../services/html_importer.dart';
import 'bottom_toolbar.dart';
import 'layer_panel.dart';
import 'property_panel.dart';
import 'render_area.dart';
import 'timeline_panel.dart';

/// 渲染页：整个编辑工作区。
class RenderPage extends ConsumerWidget {
  const RenderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proj = ref.watch(projectProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        const Positioned.fill(child: RenderArea()),
                        const Align(
                          alignment: Alignment.bottomLeft,
                          child: BottomToolbar(),
                        ),
                        Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              proj.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _actionButton(context, ref, Icons.upload_file,
                                    '导入 HTML', () => _importHtml(context, ref)),
                                const SizedBox(width: 6),
                                _actionButton(context, ref, Icons.ios_share,
                                    '导出', () => _exportHtml(context, ref)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 右侧属性 + 图层
                  SizedBox(
                    width: 252,
                    child: Column(
                      children: [
                        const PropertyPanel(),
                        const SizedBox(height: 8),
                        const Expanded(child: LayerPanel()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const TimelinePanel(),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(
      BuildContext context,
      WidgetRef ref,
      IconData icon,
      String tooltip,
      VoidCallback onTap) {
    return Material(
      color: const Color(0xE618181C),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 20, color: const Color(0xFF9E9E9E)),
          ),
        ),
      ),
    );
  }

  Future<void> _importHtml(BuildContext context, WidgetRef ref) async {
    final proj = ref.read(projectProvider);
    final ok = await HtmlImporter.import(proj);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '已导入并新增为一个层' : '导入失败或已取消')),
    );
  }

  Future<void> _exportHtml(BuildContext context, WidgetRef ref) async {
    final proj = ref.read(projectProvider);
    final html = proj.export();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${_safeName(proj.name)}.html');
    await file.writeAsString(html);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已导出：${file.path}')),
    );
  }

  String _safeName(String n) =>
      n.isEmpty ? 'animl' : n.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}