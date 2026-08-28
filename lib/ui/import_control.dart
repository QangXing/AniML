import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/presets.dart';
import '../services/html_import.dart';
import 'widgets/press_scale.dart';

/// 左上角“导入 HTML”毛玻璃按钮 + 导入方式弹窗。
class ImportControl extends StatelessWidget {
  const ImportControl({super.key, required this.onHtml});

  /// 导入成功后回调新的 HTML 源码。
  final ValueChanged<String> onHtml;

  @override
  Widget build(BuildContext context) {
    return GlassBackdrop(
      radius: 12,
      child: Material(
        color: Colors.transparent,
        child: PressScale(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _showImportSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.upload_file, size: 20, color: AppTheme.pureGrey),
                  SizedBox(width: 8),
                  Text('导入 HTML', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showImportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return GlassBackdrop(
          radius: 24,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.glassColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('导入 HTML（.html）',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 16),
                _SheetButton(
                  icon: Icons.folder_open,
                  label: '从文件选择',
                  onTap: () async {
                    final html = await HtmlImport.pickHtmlFile();
                    if (html != null && context.mounted) {
                      onHtml(html);
                      Navigator.of(context).pop();
                    }
                  },
                ),
                const SizedBox(height: 10),
                _SheetButton(
                  icon: Icons.paste,
                  label: '粘贴 HTML 代码',
                  onTap: () {
                    Navigator.of(context).pop();
                    _openPasteDialog(context);
                  },
                ),
                const SizedBox(height: 10),
                _SheetButton(
                  icon: Icons.auto_awesome,
                  label: '载入示例页面',
                  onTap: () {
                    Navigator.of(context).pop();
                    onHtml(kDefaultHtml);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  dynamic _openPasteDialog(BuildContext context) async {
    final html = await _pasteDialog(context);
    if (html != null && context.mounted) {
      onHtml(html);
    }
    return null;
  }

  Future<String?> _pasteDialog(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('粘贴 HTML'),
        content: TextField(
          controller: ctrl,
          maxLines: 10,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: '<html>...</html>',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          PressScale(
            pressedScale: 0.94,
            child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ),
          PressScale(
            pressedScale: 0.94,
            child: FilledButton(
              onPressed: () => ctrl.text.isNotEmpty ? Navigator.pop(ctx, ctrl.text) : null,
              child: const Text('确定'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      pressedScale: 0.96,
      child: Material(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.accent, size: 22),
                const SizedBox(width: 12),
                Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}