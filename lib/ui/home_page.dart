import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/editor_mode.dart';
import '../models/presets.dart';
import '../state/render_controller.dart';
import 'import_control.dart';
import 'widgets/edit_toolbox.dart';
import 'widgets/mode_control_bar.dart';
import 'widgets/render_stage.dart';
import 'widgets/shoot_panel.dart';

/// 主页面：毛玻璃 UI + 渲染舞台（搜索 / 更改 / 拍摄三模式）。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final RenderController _controller = RenderController()..setHtml(kDefaultHtml);
  final GlobalKey<RenderStageState> _stageKey = GlobalKey<RenderStageState>();

  Future<Uint8List?> _produceFrame() => _stageKey.currentState?.produceFrame();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setMode(EditorMode m) => _controller.setMode(m);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final mode = _controller.mode;
          return Stack(
            fit: StackFit.expand,
            children: [
              // 背景
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFDFDFF), Color(0xFFF1F3F6)],
                  ),
                ),
              ),
              // 渲染舞台
              RenderStage(key: _stageKey, controller: _controller),

              // 左上角导入
              Positioned(
                top: 20,
                left: 24,
                child: ImportControl(onHtml: _controller.setHtml),
              ),

              // 录制指示
              if (_controller.recording)
                const Positioned(top: 20, right: 24, child: _RecordingBadge()),

              // 左下角三功能
              Positioned(
                left: 24,
                bottom: 24,
                child: ModeControlBar(mode: mode, onChanged: _setMode),
              ),

              // 更改模式：右侧工具箱
              EditToolbox(
                controller: _controller,
                visible: mode == EditorMode.edit,
                onClose: () => _setMode(EditorMode.search),
              ),

              // 拍摄模式：拍摄面板
              if (mode == EditorMode.shoot)
                ShootPanel(controller: _controller, producer: _produceFrame),
            ],
          );
        },
      ),
    );
  }
}

class _RecordingBadge extends StatelessWidget {
  const _RecordingBadge();

  @override
  Widget build(BuildContext context) {
    return GlassBackdrop(
      radius: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: AppTheme.glassColor,
          borderRadius: BorderRadius.all(Radius.circular(12)),
          border: Border.fromBorderSide(BorderSide(color: AppTheme.glassBorder)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radio_button_checked, color: Color(0xFFD9534F), size: 16),
            SizedBox(width: 6),
            Text('录制中', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}