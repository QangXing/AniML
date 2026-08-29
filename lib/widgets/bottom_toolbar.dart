import 'package:flutter/material.dart';

import '../state/home_controller.dart';
import '../theme.dart';

const double _itemW = 78;
const double _itemH = 58;

/// 左下角三功能栏：搜索(放大镜) / 工具箱 / 拍摄。纯灰图标。
/// 带“滑动高亮块” + 点击弹性的微交互，动画非常顺滑。
class BottomToolbar extends StatelessWidget {
  const BottomToolbar({super.key, required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    const order = [Mode.search, Mode.tool, Mode.shoot];
    final idx = order.indexOf(controller.mode);

    return Glass(
      padding: const EdgeInsets.all(8),
      radius: 30,
      opacity: 0.92,
      child: SizedBox(
        height: _itemH,
        width: _itemW * 3,
        child: Stack(
          children: [
            // 滑动的选中高亮
            AnimatedPositioned(
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutQuart,
              left: 8 + idx * _itemW,
              top: 4,
              bottom: 4,
              width: _itemW,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0x33000000).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x14000000)),
                ),
              ),
            ),
            Row(
              children: [
                _SpringItem(
                  icon: Icons.search,
                  label: '搜索',
                  active: controller.mode == Mode.search,
                  onTap: () => controller.setMode(Mode.search),
                ),
                _SpringItem(
                  icon: Icons.handyman,
                  label: '工具箱',
                  active: controller.mode == Mode.tool,
                  onTap: () => controller.setMode(Mode.tool),
                ),
                _SpringItem(
                  icon: Icons.videocam,
                  label: '拍摄',
                  active: controller.mode == Mode.shoot,
                  onTap: () => controller.setMode(Mode.shoot),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 有按下缩放的弹簧微交互单元。
class _SpringItem extends StatefulWidget {
  const _SpringItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_SpringItem> createState() => _SpringItemState();
}

class _SpringItemState extends State<_SpringItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.86).chain(
        CurveTween(curve: Curves.easeOut)), weight: 34),
    TweenSequenceItem(tween: Tween(begin: 0.86, end: 1.04).chain(
        CurveTween(curve: Curves.easeOut)), weight: 33),
    TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0).chain(
        CurveTween(curve: Curves.easeOutBack)), weight: 33),
  ]).animate(_c);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down() {
    _c.forward(from: 0);
  }

  void _up() => _c.forward(from: 34 / 100); // 从回弹段开始，产生“按下滑入→弹起”

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? AppTheme.ink : AppTheme.subInk;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _down(),
      onTapUp: (_) => _up(),
      onTapCancel: () => _c.forward(from: 34 / 100),
      child: SizedBox(
        width: _itemW,
        height: _itemH,
        child: ScaleTransition(
          scale: _scale,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 选中态图标淡入为深色
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: Icon(key: ValueKey(color), widget.icon,
                    color: color, size: 24),
              ),
              const SizedBox(height: 2),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          widget.active ? FontWeight.w700 : FontWeight.w500,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}