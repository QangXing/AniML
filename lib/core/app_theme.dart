import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 白色简洁风 + 毛玻璃主题。
class AppTheme {
  AppTheme._();

  /// 全局毛玻璃面板使用的背景模糊强度。
  static const double glassBlur = 14.0;

  /// 毛玻璃面板背景（半透明白）。
  static const Color glassColor = Color(0xB3FFFFFF); // ~70% 白

  /// 面板细边框（半透明白，制造玻璃感）。
  static const Color glassBorder = Color(0x66FFFFFF);

  /// 纯灰色（图标要求的“纯灰色”）。
  static const Color pureGrey = Color(0xFF9E9E9E);

  /// 文字主色（深灰，柔和，不纯黑）。
  static const Color textPrimary = Color(0xFF3A3F45);

  /// 文字次要色。
  static const Color textSecondary = Color(0xFF8A9099);

  /// 主题强调色（克制的冰蓝，用于选中态）。
  static const Color accent = Color(0xFF5B7CFA);

  /// 背景色——极浅的冷白渐变。
  static const Color backgroundTop = Color(0xFFFDFDFF);
  static const Color backgroundBottom = Color(0xFFF1F3F6);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: null,
      scaffoldBackgroundColor: backgroundTop,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
        surface: Colors.white,
      ),
    );
    return base.copyWith(
      splashFactory: InkRipple.splashFactory,
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
    );
  }

  /// 背景渐变装饰。
  static Gradient backgroundGradient() => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [backgroundTop, backgroundBottom],
      );

  /// 让一个矩形背景变成毛玻璃面板。
  static BoxDecoration glassDecoration({
    double radius = 20,
    Color fill = glassColor,
  }) {
    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: glassBorder, width: 1),
    );
  }
}

/// 给 [child] 外层叠一层高斯模糊，实现真正的毛玻璃。
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({
    super.key,
    required this.child,
    this.radius = AppTheme.glassBlur,
  });

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: radius, sigmaY: radius),
        child: child,
      ),
    );
  }
}