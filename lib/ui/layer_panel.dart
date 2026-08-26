import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/project_controller.dart';

/// 右侧图层面板：列出所有 HTML 层，可显隐、锁定、拖拽排序、置顶编辑。
class LayerPanel extends ConsumerWidget {
  const LayerPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proj = ref.watch(projectProvider);
    final layers = proj.layers;

    return Container(
      width: 240,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xE618181C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                const Text('图层',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: '新建层',
                  onPressed: () {
                    proj.addLayer(name: '新层${layers.length + 1}');
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: '删除选中层',
                  onPressed: proj.activeLayerId == null
                      ? null
                      : () => proj.removeLayer(proj.activeLayerId!),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) newIndex -= 1;
                proj.reorderLayer(layers[oldIndex].id, newIndex);
              },
              children: [
                for (var i = 0; i < layers.length; i++)
                  _LayerTile(
                    key: ValueKey(layers[i].id),
                    proj: proj,
                    layerId: layers[i].id,
                    name: layers[i].name,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerTile extends ConsumerWidget {
  const _LayerTile({
    super.key,
    required this.proj,
    required this.layerId,
    required this.name,
  });

  final ProjectController proj;
  final String layerId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = proj.layers.firstWhere((x) => x.id == layerId);
    final selected = proj.activeLayerId == layerId;
    final visible = l.visible;
    final locked = l.locked;

    void maybe(Action fn) =>
        !locked ? fn() : null;

    return Material(
      color: selected ? const Color(0xFF24243C) : Colors.transparent,
      child: InkWell(
        onTap: () => proj.setActiveLayer(selected ? null : layerId),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: Icon(visible ? Icons.visibility : Icons.visibility_off,
                    size: 18),
                onPressed: () => proj.setLayerFlags(layerId, visible: !visible),
              ),
              GestureDetector(
                onTap: () => maybe(() => proj.setLayerFlags(layerId, locked: !locked)),
                child: Icon(
                  locked ? Icons.lock : Icons.lock_open,
                  size: 16,
                  color: locked ? Colors.orange : Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              ReorderableDragStartListener(
                index: proj.layers.indexWhere((x) => x.id == layerId),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.drag_indicator, size: 18, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef Action = void Function();