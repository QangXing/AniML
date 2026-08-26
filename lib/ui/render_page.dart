import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../controllers/project_controller.dart';
import '../services/html_importer.dart';
import '../utils/constants.dart';
import 'bottom_toolbar.dart';
import 'glass.dart';
import 'layer_panel.dart';
import 'property_panel.dart';
import 'render_area.dart';
import 'timeline_panel.dart';

/// 渲染页：整个编辑工作区（简洁毛玻璃风格）。
class RenderPage extends ConsumerWidget {
  const RenderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proj = ref.watch(projectProvider);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          const Positioned.fill(child: RenderArea()),
                          // 顶部标题（磨砂胶囊）
                          Positioned(
                            top: 12,
                            left: 12,
                            child: GlassPanel(
                              tintOpacity: 0.08,
                              blur: 18,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF6FA0FF),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    proj.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFFEDF0F5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // 右上角操作按钮
                          Positioned(
                            right: 12,
                            top: 12,
                            child: GlassPanel(
                              tintOpacity: 0.08,
                              blur: 18,
                              borderRadius: 999,
                              padding: const EdgeInsets.all(6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _glassIcon(
                                    Icons.upload_file,
                                    '导入 HTML',
                                    () => _importHtml(context, ref),
                                  ),
                                  const SizedBox(width: 2),
                                  _glassIcon(
                                    Icons.ios_share,
                                    '导出',
                                    () => _exportHtml(context, ref),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Positioned(
                            left: 16,
                            bottom: 16,
                            child: BottomToolbar(),
                          ),
                        ],
                      ),
                    ),
                    // 右侧属性 + 图层
                    SizedBox(
                      width: 260,
                      child: Column(
                        children: const [
                          Expanded(child: PropertyPanel()),
                          SizedBox(height: 8),
                          Expanded(child: LayerPanel()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: TimelinePanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassIcon(IconData icon, String tooltip, VoidCallback onTap) {
    return GlassButton(
      onTap: onTap,
      shape: BoxShape.circle,
      padding: const EdgeInsets.all(9),
      child: Tooltip(
        message: tooltip,
        child: Icon(icon, size: 20, color: AppConstants.iconGray),
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