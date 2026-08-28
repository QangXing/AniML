import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'ui/home_page.dart';

/// 应用根组件。
class RenderStudioApp extends StatelessWidget {
  const RenderStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HTML Render Studio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomePage(),
    );
  }
}