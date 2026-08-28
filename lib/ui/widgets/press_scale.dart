import 'package:flutter/material.dart';

/// 全局按压缩放反馈：按下轻微缩小，松开丝滑回弹。
///
/// 监听指针按下 / 抬起 / 取消驱动 [AnimatedScale]，不干预子组件自身的点击逻辑，
/// 因此可无侵入地包裹任意 InkWell / 按钮。
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.pressedScale = 0.94,
    this.duration = const Duration(milliseconds: 130),
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;

  /// 按下时的缩放比例（越小回弹越明显）。
  final double pressedScale;

  /// 动画时长——保持简短，营造“丝滑”而非“拖沓”。
  final Duration duration;

  final Curve curve;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}