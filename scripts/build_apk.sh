#!/usr/bin/env bash
# AniML Android 打包脚本
# 用法：
#   ./scripts/build_apk.sh                # debug 包
#   ./scripts/build_apk.sh --release      # release 包（当前用 debug 签名）
# 前置：已安装 Flutter SDK 与 Android SDK（ANDROID_HOME 已设置）。

set -e
cd "$(dirname "$0")/.."

echo "==> flutter pub get"
flutter pub get

echo "==> flutter analyze"
flutter analyze

BUILD_MODE="debug"
if [[ "$1" == "--release" ]]; then
  BUILD_MODE="release"
fi

echo "==> flutter build apk --${BUILD_MODE}"
flutter build apk --${BUILD_MODE}

echo ""
echo "构建完成。产物目录："
ls -lh build/app/outputs/flutter-apk/*.apk 2>/dev/null || ls -lh build/app/outputs/apk/*/*.apk 2>/dev/null