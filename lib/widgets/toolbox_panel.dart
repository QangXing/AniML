import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/home_controller.dart';
import '../theme.dart';

/// 右侧拉出的工具箱：可改渲染区长/宽(像素)、像素比(显示缩放)、HTML 列表与导入。
class ToolBoxPanel extends StatelessWidget {
  const ToolBoxPanel({
    super.key,
    required this.controller,
    required this.onImportHtml,
  });

  final HomeController controller;
  final Future<void> Function() onImportHtml;

  static const List<(int, int, String)> _presets = [
    (1080, 1920, '1080×1920'),
    (1440, 2560, '1440×2560'),
    (1920, 1080, '1920×1080'),
    (1024, 1024, '1:1'),
  ];

  @override
  Widget build(BuildContext context) {
    final cfg = controller.config;
    return LayoutBuilder(
      builder: (context, constraints) {
        // 高度上限：可用高度减去底部工具栏等留白，保证下方“导入 HTML”不被遮挡且可滚动。
        final avail = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final maxH = (avail - 110).clamp(220.0, 4000.0);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Glass(
            radius: 20,
            blur: 22,
            opacity: 0.94,
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
            child: SizedBox(
              width: 264,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              Row(
                children: [
                  const Text('工具箱',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => controller.setToolBox(false),
                    icon: const Icon(Icons.close, color: AppTheme.subInk),
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SectionTitle('渲染区尺寸（真实像素）'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _NumField(
                      label: '宽 W',
                      value: cfg.pixelWidth,
                      onChanged: (v) => controller.updateConfig(
                          controller.config..pixelWidth = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NumField(
                      label: '高 H',
                      value: cfg.pixelHeight,
                      onChanged: (v) => controller.updateConfig(
                          controller.config..pixelHeight = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _presets
                    .map((p) => ActionChip(
                          label: Text(p.$3, style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(color: AppTheme.hairline),
                          labelStyle: const TextStyle(color: AppTheme.ink),
                          onPressed: () => controller.updateConfig(
                              controller.config
                                ..pixelWidth = p.$1
                                ..pixelHeight = p.$2),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 18),

              _SectionTitle('相机缩放（镜头放大比例）'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DoubleField(
                      label: '缩放',
                      value: controller.camera.scale,
                      onChanged: (v) => controller.updateCamera(
                          controller.camera.copyWith(scale: v.clamp(0.03, 10.0))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DoubleField(
                      label: '像素比',
                      value: cfg.pixelScale,
                      onChanged: (v) => controller.updateConfig(
                          controller.config..pixelScale = v.clamp(0.1, 3.0)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '屏幕显示尺寸 = 渲染像素 × 像素比',
                style: const TextStyle(color: AppTheme.subInk, fontSize: 11),
              ),
              const SizedBox(height: 18),

              _SectionTitle('旋转角度'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final deg in const [0, 90, 180, 270, 360])
                    ChoiceChip(
                      label: Text('$deg°',
                          style: const TextStyle(fontSize: 12)),
                      selected: controller.camera.rotationDegrees == deg,
                      selectedColor: AppTheme.ink,
                      backgroundColor: Colors.transparent,
                      side: BorderSide(
                        color: controller.camera.rotationDegrees == deg
                            ? AppTheme.ink
                            : AppTheme.hairline,
                      ),
                      labelStyle: TextStyle(
                        color: controller.camera.rotationDegrees == deg
                            ? Colors.white
                            : AppTheme.ink,
                      ),
                      onSelected: (_) => controller.updateCamera(
                          controller.camera.copyWith(rotationDegrees: deg)),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              _SectionTitle('HTML 内容'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.hairline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: controller.selectedHtml,
                    isExpanded: true,
                    icon: const Icon(Icons.expand_more, color: AppTheme.subInk),
                    hint: const Text('选择 HTML 页面',
                        style: TextStyle(color: AppTheme.subInk, fontSize: 13)),
                    items: [
                      for (var i = 0; i < controller.htmlPages.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(controller.htmlPages[i].name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13)),
                        ),
                    ],
                    onChanged: (v) =>
                        v != null ? controller.selectHtml(v) : null,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onImportHtml,
                      icon: const Icon(Icons.file_open,
                          size: 18, color: AppTheme.subInk),
                      label: const Text('导入 HTML',
                          style:
                              TextStyle(fontSize: 13, color: AppTheme.ink)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.hairline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (controller.selectedHtml >= 0)
                    IconButton(
                      onPressed: () =>
                          controller.deleteHtml(controller.selectedHtml),
                      icon: const Icon(Icons.delete_outline,
                          color: AppTheme.subInk, size: 20),
                    ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
    },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 12, color: AppTheme.subInk, fontWeight: FontWeight.w600),
      );
}

class _NumField extends StatelessWidget {
  const _NumField({required this.label, required this.value, required this.onChanged});
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = TextEditingController(text: '$value');
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.subInk)),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 13, color: AppTheme.ink),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.subInk),
              ),
            ),
            onSubmitted: (s) =>
                onChanged(int.tryParse(s) ?? value),
          ),
        ),
      ],
    );
  }
}

class _DoubleField extends StatelessWidget {
  const _DoubleField({required this.label, required this.value, required this.onChanged});
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = TextEditingController(text: value.toStringAsFixed(2));
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.subInk)),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            style: const TextStyle(fontSize: 13, color: AppTheme.ink),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.subInk),
              ),
            ),
            onSubmitted: (s) => onChanged(double.tryParse(s) ?? value),
          ),
        ),
      ],
    );
  }
}