import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/render_page.dart';
import 'controllers/project_controller.dart';

class AniMLApp extends ConsumerWidget {
  const AniMLApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'AniML',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: _theme(),
      darkTheme: _theme(),
      home: const HomeShell(),
    );
  }

  ThemeData _theme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6FA0FF),
        secondary: Color(0xFF8B5CFF),
        surface: Color(0x00FFFFFF),
        onSurface: Color(0xFFEDF0F5),
      ),
      scaffoldBackgroundColor: const Color(0xFF0B0D16),
      dividerColor: const Color(0x1FFFFFFF),
      fontFamilyFallback: const ['PingFang SC', 'Noto Sans SC'],
    );
  }
}

/// 工程根入口：加载样例工程并进入渲染页。
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    if (project == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const RenderPage();
  }
}