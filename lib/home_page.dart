import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../services/html_import_service.dart';
import '../services/render_engine.dart';
import '../services/shoot_service.dart';
import '../state/home_controller.dart';
import '../theme.dart';
import 'widgets/app_logo_bar.dart';
import 'widgets/bottom_toolbar.dart';
import 'widgets/camera_viewport.dart';
import 'widgets/shoot_panel.dart';
import 'widgets/toolbox_panel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HomeController _controller = HomeController();
  final RenderEngine _engine = RenderEngine();
  late final ShootService _shoot;
  bool _inited = false;
  String? _lastVideoPath;

  @override
  void initState() {
    super.initState();
    _shoot = ShootService(_controller, _engine);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    // 初始把渲染区适配到屏幕内（居中、可缩放）
    final sz = MediaQuery.sizeOf(context);
    final dw = _controller.config.displayWidth;
    final dh = _controller.config.displayHeight;
    final fit = math.min(sz.width / dw, sz.height / dh) * 0.92;
    _controller.updateCamera(
      Camera(position: Offset.zero, scale: fit.clamp(0.02, 1.5), rotation: 0),
    );
  }

  Future<void> _importHtml() async {
    final page = await HtmlImportService.instance.pick();
    if (page != null && mounted) {
      _controller.addHtml(page);
      _toast('已导入 ${page.name}');
    }
  }

  void _toggleRecord() {
    if (_shoot.isRunning) {
      _shoot.stop();
      _toast('已停止拍摄');
      return;
    }
    if (!_controller.hasHtml) {
      _toast('请先导入并选择 HTML');
      return;
    }
    final cfg = _controller.config;
    _shoot.start(
      seconds: _controller.shootSeconds,
      fps: _controller.shootFps,
      width: cfg.pixelWidth,
      height: cfg.pixelHeight,
      onDone: _onVideoDone,
      onError: (e) => _toast(e),
    );
  }

  void _onVideoDone(String path) {
    _lastVideoPath = path;
    _toast('拍摄完成，mp4 已生成');
    showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close',
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, __, ___) => _buildDoneCard(path),
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
  }

  Widget _buildDoneCard(String path) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Glass(
          padding: const EdgeInsets.all(20),
          radius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                color: AppTheme.ink, size: 40),
            const SizedBox(height: 12),
            const Text('拍摄完成',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink)),
            const SizedBox(height: 4),
            const Text('mp4 已生成并保存到临时目录',
                style: TextStyle(fontSize: 13, color: AppTheme.subInk)),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭',
                      style: TextStyle(color: AppTheme.ink, fontSize: 13)),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _shoot.share(path);
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.ink),
                  child: const Text('分享',
                      style:
                          TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _toast(String msg) =>
      Fluttertoast.showToast(msg: msg, gravity: ToastGravity.BOTTOM);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final toolVisible = _controller.mode == Mode.tool;
            return Stack(
              children: [
                // 相机视口（整个屏幕）
                Positioned.fill(
                  child: CameraViewport(
                      controller: _controller, engine: _engine),
                ),

                // 顶部标题（毛玻璃 + AniML logo + 浮动动画）
                Positioned(
                  left: 16,
                  top: 12,
                  child: IgnorePointer(child: const AppLogoBar()),
                ),

                // 录制指示红点（闪烁）
                if (_controller.isRecording)
                  Positioned(
                    right: 16,
                    top: 12,
                    child: _RecBadge(),
                  ),

                // 右下：左侧工具箱开关（工具模式下）
                if (toolVisible)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: GestureDetector(
                      onTap: _controller.toggleToolBox,
                      child: Glass(
                        radius: 22,
                        opacity: 0.86,
                        padding: const EdgeInsets.all(10),
                        child: AnimatedRotation(
                          turns: _controller.toolBoxOpen ? 0.5 : 0,
                          duration: const Duration(milliseconds: 240),
                          child: const Icon(Icons.chevron_left,
                              color: AppTheme.subInk, size: 20),
                        ),
                      ),
                    ),
                  ),

                // 左侧：工具箱面板（从右拉出 + 淡入）
                Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutQuart,
                    offset: Offset(toolVisible && _controller.toolBoxOpen
                        ? 0
                        : 1.12, 0),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 240),
                      opacity: toolVisible && _controller.toolBoxOpen ? 1 : 0,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 56),
                        child: ToolBoxPanel(
                          controller: _controller,
                          onImportHtml: _importHtml,
                        ),
                      ),
                    ),
                  ),
                ),

                // 底部：左下角三功能栏
                Positioned(
                  left: 16,
                  bottom: 18,
                  child: BottomToolbar(controller: _controller),
                ),

                // 拍摄面板（出场弹入）
                if (_controller.mode == Mode.shoot)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 92,
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        key: const ValueKey('shoot-panel'),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutBack,
                        builder: (context, t, child) => Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, (1 - t) * 24),
                            child: child,
                          ),
                        ),
                        child: ShootPanel(
                          controller: _controller,
                          onRecordCallback: _toggleRecord,
                          onShare: (path) async {
                            final target = _lastVideoPath ?? path;
                            if (target.isNotEmpty) {
                              _shoot.share(target);
                            } else {
                              _toast('还没有可分享的视频');
                            }
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 录制红点徽标：红色圆点呼吸闪烁 + REC 文字轻微跳动。
class _RecBadge extends StatefulWidget {
  @override
  State<_RecBadge> createState() => _RecBadgeState();
}

class _RecBadgeState extends State<_RecBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.0,
      upperBound: 1.0);
  late final Animation<double> _pulse = CurvedAnimation(
      parent: _c, curve: Curves.easeInOutSine);

  @override
  void initState() {
    super.initState();
    _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 20,
      opacity: 0.9,
      blur: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: 0.8 + _pulse.value * 0.4,
              child: Opacity(
                opacity: 0.5 + _pulse.value * 0.5,
                child: const Icon(Icons.fiber_manual_record,
                    color: Color(0xFFE0313A), size: 14),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'REC',
              style: TextStyle(
                color: const Color(0xFFE0313A)
                    .withAlpha((165 + _pulse.value * 90).round()),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}