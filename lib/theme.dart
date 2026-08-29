import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// 白色简洁 + 毛玻璃主题。
class AppTheme {
  AppTheme._();

  static const Color bg = Color(0xFFF6F6F8); // 极浅的灰白背景
  static const Color ink = Color(0xFF1C1C1E); // 主文字
  static const Color subInk = Color(0xFF8E8E93); // 次要文字 / 图标灰
  static const Color hairline = Color(0xFFE5E5EA); // 细边框
  static const Color accent = Color(0xFF7C7C80); // 选中态中性灰

  /// 毛玻璃地调用。
  static const Color _glassBorder = Color(0x33FFFFFF);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8E8E93),
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamilyFallback: const ['PingFang SC', 'HarmonyOS Sans SC'],
      splashFactory: InkRipple.splashFactory,
    );
  }
}

/// 毛玻璃容器：白色半透明 + 模糊 + 极细描边。
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.blur = 18.0,
    this.opacity = 0.86,
    this.radius = 26.0,
    this.padding = EdgeInsets.zero,
    this.borderRadius,
  });

  final Widget child;
  final double blur;
  final double opacity;
  final double radius;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: r,
            border: Border.all(color: AppTheme._glassBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}