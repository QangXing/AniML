import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// 简洁毛玻璃（Glassmorphism）风格基础组件。
//
// - [AppBackground]：全屏柔和渐变底色 + 大范围柔光光斑，为毛玻璃提供半透明的底层层次。
// - [GlassPanel]：可复用的磨砂面板容器。
// - [GlassButton]：磨砂圆角 / 圆形按钮。

/// 全屏背景：横向渐变 + 柔光光斑，形成毛玻璃可透出的色彩层次。
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF0A0C13),
            Color(0xFF10172B),
            Color(0xFF0B0D16),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -140,
            right: -80,
            child: _Glow(size: 360, color: const Color(0xFF2D5BFF).withOpacity(0.28)),
          ),
          Positioned(
            bottom: 60,
            left: -120,
            child: _Glow(size: 420, color: const Color(0xFF8B5CFF).withOpacity(0.16)),
          ),
          Positioned(
            top: 240,
            right: 220,
            child: _Glow(size: 200, color: const Color(0xFF2BC0B4).withOpacity(0.12)),
          ),
          child,
        ],
      ),
    );
  }
}

/// 柔光光斑（径向渐变圆）。
class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }
}

/// 磨砂面板：背景模糊 + 半透明衬托 + 细描边 + 圆角 + 柔和投影。
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding,
    this.tint = Colors.white,
    this.tintOpacity = 0.07,
    this.borderOpacity = 0.14,
    this.blur = 26,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsets? padding;
  final Color tint;
  final double tintOpacity;
  final double borderOpacity;
  final double blur;
  final HitTestBehavior behavior;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint.withOpacity(tintOpacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withOpacity(borderOpacity),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: GestureDetector(
            behavior: behavior,
            child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ),
        ),
      ),
    );
  }
}

/// 磨砂圆形 / 胶囊按钮（用于工具栏）。
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.onTap,
    required this.child,
    this.shape = BoxShape.rectangle,
    this.borderRadius = 14,
    this.tintOpacity = 0.06,
    this.borderOpacity = 0.16,
    this.padding = const EdgeInsets.all(10),
  });

  final VoidCallback onTap;
  final Widget child;
  final BoxShape shape;
  final double borderRadius;
  final double tintOpacity;
  final double borderOpacity;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: shape == BoxShape.circle
            ? BorderRadius.circular(100)
            : BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(tintOpacity),
              shape: shape,
              borderRadius: shape == BoxShape.circle
                  ? null
                  : BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withOpacity(borderOpacity),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}