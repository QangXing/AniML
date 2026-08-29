import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../state/home_controller.dart';

/// 注入到每个加载页面里的“高像素截图”脚本。
/// 通过 foreignObject -> SVG -> Canvas 把整页按目标像素分辨率栅格化，返回 PNG base64。
const String _captureScript = r'''
(function(){
  if (window.__capInstalled) return;
  window.__capInstalled = true;
  var bgCache = '#ffffff';
  window.__setBg = function(c){ bgCache = c || '#ffffff'; };
  window.__capture = function(w, h){
    return new Promise(function(resolve){
      try {
        var root = document.documentElement;
        var body = document.body || root;
        var sw = Math.max(body.scrollWidth, root.scrollWidth, window.innerWidth);
        var sh = Math.max(body.scrollHeight, root.scrollHeight, window.innerHeight);
        var scale = Math.max(w / sw, h / sh);
        var ns = 'http://www.w3.org/2000/svg';
        var svg = document.createElementNS(ns, 'svg');
        svg.setAttribute('xmlns', ns);
        svg.setAttribute('width', String(w));
        svg.setAttribute('height', String(h));
        svg.setAttribute('viewBox', '0 0 ' + sw + ' ' + sh);
        var foreign = document.createElementNS(ns, 'foreignObject');
        foreign.setAttribute('x', '0'); foreign.setAttribute('y', '0');
        foreign.setAttribute('width', String(sw));
        foreign.setAttribute('height', String(sh));
        var nodal = root;
        foreign.appendChild(nodal.cloneNode(true));
        svg.appendChild(foreign);
        var x = new XMLSerializer().serializeToString(svg);
        var svgUrl = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(x);
        var img = new Image();
        img.onload = function(){
          try {
            var canvas = document.createElement('canvas');
            canvas.width = w; canvas.height = h;
            var ctx = canvas.getContext('2d');
            ctx.fillStyle = bgCache;
            ctx.fillRect(0, 0, w, h);
            ctx.drawImage(img, 0, 0, w, h);
            resolve(canvas.toDataURL('image/png'));
          } catch(e){ resolve(null); }
        };
        img.onerror = function(){ resolve(null); };
        img.src = svgUrl;
      } catch(e){ resolve(null); }
    });
  };
})();
''';

/// 渲染引擎：持有 WebViewController，负责加载 HTML 与高像素抓帧。
class RenderEngine extends ChangeNotifier {
  RenderEngine() {
    _created = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..addJavaScriptChannel(
        'flutterCapture',
        onMessageReceived: (msg) => handleCaptureMessage(msg.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) => _injectCapture(),
          onWebResourceError: (_) {},
        ),
      );
  }

  late final WebViewController _created;
  Uint8List? _loaded;
  bool _ready = false;

  /// 最近一次抓到的 PNG 帧（可用来在背景上叠一层淡化的 HTML）。
  Uint8List? lastSnapshot;

  WebViewController get controller => _created;
  bool get isReady => _ready;
  Uint8List? get loadedHtml => _loaded;

  /// 更换所渲染的 HTML 内容。
  void load(HtmlPage? page) {
    final bytes = page?.htmlBytes;
    if (bytes == null) {
      _loaded = null;
      _ready = true;
      notifyListeners();
      return;
    }
    if (identical(bytes, _loaded)) return;
    _loaded = bytes;
    final b64 = base64Encode(bytes);
    final uri =
        'data:text/html;charset=utf-8;base64,$b64';
    _created.loadRequest(Uri.parse(uri));
    notifyListeners();
  }

  void _injectCapture() {
    _ready = true;
    _created.runJavaScript(_captureScript);
    notifyListeners();
  }

  /// 抓取渲染区在 [w] x [h] 像素下的实时 PNG。失败返回 null。
  Future<Uint8List?> capture(int w, int h, {String? background}) async {
    if (!_ready) return null;
    if (background != null) {
      await _created.runJavaScript(
          'try{window.__setBg && window.__setBg("${background}");}catch(e){}');
    }
    final resolveScript = 'window.__capture($w,$h).then(function(uri){'
        'if(uri){window.flutterCapture.postMessage(uri);}'
        'else{window.flutterCapture.postMessage("__NULL__");}'
        '});';
    final completer = Completer<Uint8List?>();
    final sub = _stream.stream.listen((msg) {
      if (!completer.isCompleted) completer.complete(msg);
    });
    try {
      await _created.runJavaScript(resolveScript);
      final r = await completer.future.timeout(const Duration(seconds: 12));
      return r;
    } catch (_) {
      return null;
    } finally {
      sub.cancel();
    }
  }

  final StreamController<Uint8List?> _stream = StreamController.broadcast();

  /// 处理来自 WebView 的 JS 数据。
  void handleCaptureMessage(String? message) {
    if (message == null || message == '__NULL__') {
      _stream.add(null);
      return;
    }
    try {
      final base64 = message.contains(',') ? message.split(',').last : message;
      final png = base64Decode(base64);
      lastSnapshot = png;
      _stream.add(png);
    } catch (_) {
      _stream.add(null);
    }
  }

  @override
  void dispose() {
    _stream.close();
    super.dispose();
  }
}

/// 把 [engine] 的 WebView 渲染出来。JS 到 Dart 的桥已在引擎构造时挂好。
class RenderAreaView extends StatefulWidget {
  const RenderAreaView({super.key, required this.engine, this.html});

  final RenderEngine engine;
  final HtmlPage? html;

  @override
  State<RenderAreaView> createState() => _RenderAreaViewState();
}

class _RenderAreaViewState extends State<RenderAreaView> {
  @override
  void initState() {
    super.initState();
    widget.engine.load(widget.html);
  }

  @override
  void didUpdateWidget(covariant RenderAreaView old) {
    super.didUpdateWidget(old);
    if (old.html?.htmlBytes != widget.html?.htmlBytes) {
      widget.engine.load(widget.html);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: widget.engine.controller);
  }
}