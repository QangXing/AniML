import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_page.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 竖屏锁定
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: AppTheme.bg,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const HighResHtmlApp());
}

/// 全局 SnackBar 通道，供 Dart 代码在任意时机弹出提示。
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class HighResHtmlApp extends StatelessWidget {
  const HighResHtmlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '高像素 HTML 渲染',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.light(),
      home: const HomePage(),
    );
  }
}