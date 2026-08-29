import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

const String kLogoAsset = 'assets/logo/logo.jpg';

/// 顶栏：AniML logo + 应用名。带动画：轻微上下浮动 + 呼吸缩放，非常顺滑。
class AppLogoBar extends StatefulWidget {
  const AppLogoBar({super.key});

  @override
  State<AppLogoBar> createState() => _AppLogoBarState();
}

class _AppLogoBarState extends State<AppLogoBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatC =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4800), repeat: true);
  late final Animation<double> _float = Tween<double>(begin: 0, end: 1).animate(
    CurvedAnimation(parent: _floatC, curve: Curves.easeInOutSine),
  );

  @override
  void dispose() {
    _floatC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 22,
      opacity: 0.72,
      blur: 16,
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 浮动 + 呼吸的 logo
          AnimatedBuilder(
            animation: _float,
            builder: (context, _) {
              final t = _float.value;
              final dy = -3.5 * math.sin(t * math.pi);
              final breathe = 1.0 + 0.012 * math.sin(t * math.pi);
              return Transform.translate(
                offset: Offset(0, dy),
                child: Transform.scale(
                  scale: breathe,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      kLogoAsset,
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('高像素 HTML 渲染',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink)),
              SizedBox(height: 1),
              Text('◀ ▶  AniML', // 呼应 logo 的代码+播放语义
                  style: TextStyle(fontSize: 10, color: AppTheme.subInk)),
            ],
          ),
        ],
      ),
    );
  }
}