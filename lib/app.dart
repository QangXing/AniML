import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/render_page.dart';
import 'controllers/project_controller.dart';
import 'utils/constants.dart';

class AniMLApp extends ConsumerWidget {
  const AniMLApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ThemeMode.dark;
    return MaterialApp(
      title: 'AniML',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF2962FF),
        scaffoldBackgroundColor: const Color(0xFF111113),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF2962FF),
        scaffoldBackgroundColor: const Color(0xFF111113),
      ),
      home: const HomeShell(),
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