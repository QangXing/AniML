import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/js_bridge.dart';

/// 管理每个层对应的 InAppWebViewController，并提供注入/求值能力。
class WebViewPool extends ChangeNotifier {
  WebViewPool();

  final Map<String, InAppWebViewController> _controllers = {};

  bool has(String layerId) => _controllers.containsKey(layerId);

  void register(String layerId, InAppWebViewController c) {
    _controllers[layerId] = c;
    notifyListeners();
  }

  void unregister(String layerId) {
    _controllers.remove(layerId);
    notifyListeners();
  }

  /// 层尚未就绪时，稍后重试。
  Future<void> evaluate(String layerId, String js, {int retry = 3}) async {
    final c = _controllers[layerId];
    if (c == null) {
      if (retry > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await evaluate(layerId, js, retry: retry - 1);
      }
      return;
    }
    await c.evaluateJavascript(source: js);
  }

  /// 初次载入后注入 AniML 全局脚本。
  Future<void> bootstrap(String layerId) async {
    await evaluate(layerId, JsBridge.bootstrap);
  }

  Future<void> selectElement(String layerId, String selector) async {
    await evaluate(layerId,
        '${JsBridge.globalObject}.selectElement(${_jsonString(selector)});');
  }

  Future<void> setLayerVisible(String layerId, bool visible) async {
    await evaluate(layerId,
        '${JsBridge.globalObject}.setLayerVisible(${visible ? 'true' : 'false'});');
  }

  static String _jsonString(String s) => "'${s.replaceAll("'", "\\'")}'";

  void clear() {
    _controllers.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _controllers.clear();
    super.dispose();
  }
}

final webViewPoolProvider = ChangeNotifierProvider((ref) => WebViewPool());