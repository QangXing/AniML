import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/project_controller.dart';
import '../utils/constants.dart';

/// 右侧属性面板：渲染区尺寸、底色、网格、摄像机设置（摄像机模式下）。
class PropertyPanel extends ConsumerStatefulWidget {
  const PropertyPanel({super.key});

  @override
  ConsumerState<PropertyPanel> createState() => _PropertyPanelState();
}

class _PropertyPanelState extends ConsumerState<PropertyPanel> {
  late TextEditingController _wC;
  late TextEditingController _hC;
  bool _expanded = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final proj = ref.watch(projectProvider);
    _wC = TextEditingController(text: proj.canvas.width.toStringAsFixed(0))
      ..selection = TextSelection.collapsed(offset: _wC.text.length);
    _hC = TextEditingController(text: proj.canvas.height.toStringAsFixed(0))
      ..selection = TextSelection.collapsed(offset: _hC.text.length);
  }

  @override
  void dispose() {
    _wC.dispose();
    _hC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final proj = ref.watch(projectProvider);
    final canvas = proj.canvas;
    final inCamera = proj.mode == AppMode.camera;

    return Container(
      width: 240,
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xE618181C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                const Text('属性', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            const Text('渲染区', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                    child: TextField(
                  controller: _wC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: '宽', isDense: true, border: OutlineInputBorder()),
                  onSubmitted: (v) => _applySize(),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                  controller: _hC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: '高', isDense: true, border: OutlineInputBorder()),
                  onSubmitted: (v) => _applySize(),
                )),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final ratio in AppConstants.aspectRatios)
                    _ratioChip(proj, ratio),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('背景色', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    final color = await showDialog<Color>(
                      context: context,
                      builder: (_) => const _ColorPicker(),
                    );
                    if (color != null) proj.setCanvasBackground(color);
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: canvas.backgroundColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('网格',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                Switch(
                  value: proj.showGrid,
                  onChanged: (v) => proj.setGridVisible(v),
                ),
              ],
            ),
            if (inCamera) ...[
              const Divider(height: 20),
              const Text('摄像机', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: proj.camera.format,
                decoration: const InputDecoration(
                    isDense: true, border: OutlineInputBorder()),
                items: AppConstants.timelines
                    .map((f) => DropdownMenuItem(value: f.toUpperCase(), child: Text(f)))
                    .toList(),
                onChanged: (v) =>
                    proj.setCamera(format: v != null ? v.toLowerCase() : null),
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: proj.camera.fps,
                      decoration: const InputDecoration(
                          isDense: true, border: OutlineInputBorder()),
                      items: AppConstants.framerates
                          .map((f) => DropdownMenuItem(value: f, child: Text('$f fps')))
                          .toList(),
                      onChanged: (v) => proj.setCamera(fps: v),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _applySize() {
    final w = double.tryParse(_wC.text.replaceAll(',', ''));
    final h = double.tryParse(_hC.text.replaceAll(',', ''));
    if (w == null || h == null || w <= 0 || h <= 0) return;
    ref.read(projectProvider).setCanvasSize(w, h);
  }

  Widget _ratioChip(ProjectController proj, String ratio) {
    final selected = ratio != '自定义' &&
        (proj.canvas.width / proj.canvas.height)
            .toStringAsFixed(3) ==
            _ratioValue(ratio).toStringAsFixed(3);
    void Function()? onTap;
    if (ratio != '自定义') {
      onTap = () {
        final r = _ratioValue(ratio);
        final h = proj.canvas.width / r;
        proj.setCanvasSize(proj.canvas.width, h);
      };
    }
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(ratio, style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => onTap?.call(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  double _ratioValue(String ratio) {
    final parts = ratio.split(':');
    return double.parse(parts[0]) / double.parse(parts[1]);
  }
}

class _ColorPicker extends StatefulWidget {
  const _ColorPicker();

  @override
  State<_ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<_ColorPicker> {
  Color _color = Colors.white;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('渲染区背景色'),
      content: SizedBox(
        width: 300,
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in _palette)
              GestureDetector(
                onTap: () => Navigator.pop(context, c),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static const _palette = <Color>[
    Colors.white,
    Colors.black,
    Color(0xFF1A73E8),
    Color(0xFF00695C),
    Color(0xFFE53935),
    Color(0xFFF9A825),
    Color(0xFF6A1B9A),
    Color(0xFF455A64),
  ];
}