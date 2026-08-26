import 'package:flutter/material.dart';

class AppMode {
  static const int search = 0;
  static const int edit = 1;
  static const int camera = 2;
}

class AppConstants {
  AppConstants._();

  static const double toolbarIconSize = 22.0;
  static const Color iconGray = Color(0xFFB8BDC8); // 简洁低饱和灰
  static const Color iconGrayActive = Color(0xFF6FA0FF); // 高亮主题蓝
  static const Color panelText = Color(0xFFEDF0F5);
  static const Color panelTextSub = Color(0xFF9AA3B5);
  static const Color panelBorder = Color(0x26FFFFFF);
  static const Color divider = Color(0x1FFFFFFF);
  static const Color renderAreaBorder = Color(0xFFE5E5E5);
  static const Color gridColor = Color(0xFFDCDCDC);
  static const Color axisColor = Color(0xFFBDBDBD);
  static const Color playheadColor = Color(0xFFE53935);
  static const Color recRed = Color(0xFFE53935);

  static const double defaultCanvasWidth = 1920;
  static const double defaultCanvasHeight = 1080;
  static const Color defaultCanvasBackground = Color(0xFFFFFFFF);

  static const double minViewportScale = 0.1;
  static const double maxViewportScale = 5.0;

  static const List<String> aspectRatios = <String>['16:9', '4:3', '1:1', '9:16', '自定义'];
  static const List<String> timelines = <String>['MP4', 'WebM', 'GIF'];
  static const List<int> framerates = <int>[24, 30, 60];

  static const Duration defaultClipDuration = Duration(seconds: 5);
}