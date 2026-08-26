import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/project_controller.dart';
import '../services/camera_recorder.dart';
import '../utils/constants.dart';

/// 左下角工具栏：搜索 / 更改 / 摄像机（摄像机模式下显示录制控制）。
class BottomToolbar extends ConsumerStatefulWidget {
  const BottomToolbar({super.key});

  @override
  ConsumerState<BottomToolbar> createState() => _BottomToolbarState();
}

class _BottomToolbarState extends ConsumerState<BottomToolbar> {
  String _recTime = '00:00:00';

  @override
  Widget build(BuildContext context) {
    final proj = ref.watch(projectProvider);
    final inCamera = proj.mode == AppMode.camera;

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (inCamera) ...[
            _recordControl(proj),
            const SizedBox(width: 12),
          ],
          _toolButton(
            icon: Icons.travel_explore,
            active: proj.mode == AppMode.search,
            tooltip: '搜索（浏览）',
            onTap: () => proj.setMode(AppMode.search),
          ),
          const SizedBox(width: 8),
          _toolButton(
            icon: Icons.edit,
            active: proj.mode == AppMode.edit,
            tooltip: '更改（编辑）',
            onTap: () => proj.setMode(AppMode.edit),
          ),
          const SizedBox(width: 8),
          _toolButton(
            icon: Icons.videocam,
            active: proj.mode == AppMode.camera,
            tooltip: '摄像机',
            onTap: () => proj.setMode(AppMode.camera),
          ),
        ],
      ),
    );
  }

  Widget _recordControl(ProjectController proj) {
    final recording = CameraRecorder.isRecording;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1A1E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () async {
              if (recording) {
                final path = await CameraRecorder.stop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已保存录制：$path')),
                  );
                }
              } else {
                proj.seek(Duration.zero);
                proj.play();
                final ok = await CameraRecorder.start(proj);
                if (!ok && mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('无法开始录制')));
                }
              }
            },
            child: CircleAvatar(
              radius: 14,
              backgroundColor: recording ? Colors.white : AppConstants.recRed,
              child: recording
                  ? Container(
                      width: 12,
                      height: 12,
                      color: AppConstants.recRed,
                    )
                  : const Icon(Icons.radio_button_checked, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            recording ? _format(proj.playhead) : _recTime,
            style: const TextStyle(
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Widget _toolButton({
    required IconData icon,
    required bool active,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final color = active ? AppConstants.iconGrayActive : AppConstants.iconGray;
    return Material(
      color: const Color(0xCC1A1A1E),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color, size: AppConstants.toolbarIconSize),
          ),
        ),
      ),
    );
  }
}