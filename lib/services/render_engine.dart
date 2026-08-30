import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../state/home_controller.dart';

/// 注入到每个加载页面里的“高像素截图”脚本。
/// 通过 foreignObject -> SVG -> Canvas 把整页按目标像素分辨率栅格化，返回 PNG base64。
/// 捕获前先把合成线程上的动画当前值写回主线程（commitStyles），
/// 再把每个元素**当前计算样式**内联进克隆节点，让 CSS 动画的“当前帧”被如实保留，
/// 这样连续抓帧就能得到会动的画面，而不是永远定格在初始帧。
const String _captureScript = r'''
(function(){
  if (window.__capInstalled) return;
  window.__capInstalled = true;
  var bgCache = '#ffffff';
  window.__setBg = function(c){ bgCache = c || '#ffffff'; };

  // 录制虚拟时钟：拍摄时暂停页面动画，按 1/fps 逐帧拨动 currentTime，
  // 让每一帧都对应精确的动画时间，彻底摆脱“抓帧慢 → 动画已跑远 → 视频跳变”。
  window.__rec = {
    active: false,
    anims: [],
    t: 0,
    fps: 30,
    begin: function(fps) {
      this.active = true;
      this.fps = fps || 30;
      this.t = 0;
      this._snap();
      this._seekAll(0);
    },
    _snap: function() {
      var all = [];
      try { all = document.getAnimations() || []; } catch(e){ all = []; }
      this.anims = [];
      for (var i = 0; i < all.length; i++) {
        var a = all[i];
        if (!a) continue;
        try { this.anims.push(a); a.pause(); } catch(e){}
      }
    },
    _seekAll: function(ms) {
      for (var i = 0; i < this.anims.length; i++) {
        try {
          var a = this.anims[i];
          if (a.playState === 'paused') a.currentTime = ms;
        } catch(e){}
      }
    },
    seek: function(s) {
      if (!this.active) return;
      this.t = s;
      this._seekAll(s * 1000);
      // 强制同步 reflow：确保浏览器立刻按 seek 后的时间重算样式/布局，
      // 这样 getComputedStyle 与绘制都反映当前帧，而不是停在上一帧。
      try { document.body && document.body.offsetHeight; } catch(e){}
    },
    end: function() {
      this.active = false;
      for (var i = 0; i < this.anims.length; i++) {
        try {
          var a = this.anims[i];
          if (a.playState === 'paused') a.play();
        } catch(e){}
      }
      this.anims = [];
    }
  };

  window.__capture = function(w, h){
    return new Promise(function(resolve){
      try {
        // 非录制态才 commitStyles：把合成线程上的动画当前值写回主线程内联样式，
        // 让 CSS 动画当前帧被如实保留。录制态由虚拟时钟逐帧 seek 控制动画，
        // 若再 commitStyles 会把动画效果烘焙进内联样式，破坏后续 seek。
        try {
          if (!window.__rec || !window.__rec.active) {
            var anims = document.getAnimations();
            for (var i = 0; i < anims.length; i++) {
              var a = anims[i];
              if (a && typeof a.commitStyles === 'function') {
                try { a.commitStyles(); } catch (e2) {}
              }
            }
          }
        } catch (e1) {}
        var root = document.documentElement;
        var body = document.body || root;
        var sw = Math.max(body.scrollWidth, root.scrollWidth, window.innerWidth);
        var sh = Math.max(body.scrollHeight, root.scrollHeight, window.innerHeight);
        var ns = 'http://www.w3.org/2000/svg';
        var clone = root.cloneNode(true);
        // 内联当前计算样式：保持动画当前帧、变换、颜色等实际显示效果。
        var srcEls = [root].concat(Array.prototype.slice.call(root.querySelectorAll('*')));
        var dstEls = [clone].concat(Array.prototype.slice.call(clone.querySelectorAll('*')));
        for (var i = 0; i < srcEls.length && i < dstEls.length; i++) {
          try {
            var cs = window.getComputedStyle(srcEls[i]);
            var inline = '';
            for (var j = 0; j < cs.length; j++) {
              var p = cs[j];
              var v = cs.getPropertyValue(p);
              if (v) inline += p + ':' + v + ';';
            }
            dstEls[i].setAttribute('style', (dstEls[i].getAttribute('style') || '') + inline);
          } catch(e) {}
        }
        var svg = document.createElementNS(ns, 'svg');
        svg.setAttribute('xmlns', ns);
        svg.setAttribute('width', String(w));
        svg.setAttribute('height', String(h));
        svg.setAttribute('viewBox', '0 0 ' + sw + ' ' + sh);
        var foreign = document.createElementNS(ns, 'foreignObject');
        foreign.setAttribute('x', '0'); foreign.setAttribute('y', '0');
        foreign.setAttribute('width', String(sw));
        foreign.setAttribute('height', String(sh));
        foreign.appendChild(clone);
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

  /// 挂在渲染区 WebView 外面的 RepaintBoundary 的 key，
  /// 用它直接截取 WebView 当前屏幕画面（含 CSS/JS 动画），速度远快于 JS 栅格化。
  final GlobalKey captureKey = GlobalKey();

  /// 平台视图（WebView）能否被 RepaintBoundary 直接截取。
  /// 这是设备级稳定属性，缓存后不必每帧都做小图探测，定期复查即可。
  bool? _viewCaptureWorks;
  int _captureCount = 0;

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

  /// 进入录制：暂停页面动画并把录制虚拟时钟归零（从动画起点开始逐帧拍摄）。
  Future<void> beginRecord(int fps) async {
    if (!_ready) return;
    await _created.runJavaScript(
        'try{window.__rec && window.__rec.begin($fps);}catch(e){}');
  }

  /// 把录制虚拟时钟拨到 [seconds] 秒（动画从 0 开始，一帧对应一个精确时刻）。
  Future<void> seekRecord(double seconds) async {
    if (!_ready) return;
    await _created.runJavaScript(
        'try{window.__rec && window.__rec.seek($seconds);}catch(e){}');
  }

  /// 结束录制：恢复页面动画，回到实时播放。
  Future<void> endRecord() async {
    if (!_ready) return;
    await _created
        .runJavaScript('try{window.__rec && window.__rec.end();}catch(e){}');
  }

  /// 抓取渲染区在 [w] x [h] 像素下的实时 PNG。
  /// 优先用 RepaintBoundary 直取 WebView 当前渲染画面（能拍到 CSS/JS 动画），
  /// 失败时回退到 JS 整页栅格化（同样保留动画当前帧）。都失败返回 null。
  Future<Uint8List?> capture(int w, int h, {String? background}) async {
    if (!_ready) return null;
    final fromView = await _captureFromView(w, h);
    if (fromView != null) {
      lastSnapshot = fromView;
      return fromView;
    }
    final viaJs = await _captureViaJs(w, h, background: background);
    if (viaJs != null) lastSnapshot = viaJs;
    return viaJs;
  }

  /// 从渲染区 WebView 的 RepaintBoundary 直接截取当前画面。
  /// 先用小尺寸探测确认平台视图已合成进层树（否则返回 null 走 JS 回退）：
  /// 要求探测图里同时存在**不透明**像素和**有变化**的内容，
  /// 避免 SurfaceControl 设备把平台视图截成“全透明空洞”或“纯白空白”而产出坏帧。
  /// 探测结果按设备缓存（定期复查），省掉每帧一次 GPU 读 + CPU 扫描，提升抓帧速度。
  Future<Uint8List?> _captureFromView(int w, int h) async {
    final ctx = captureKey.currentContext;
    final boundary = ctx?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || !boundary.hasSize || boundary.size.isEmpty) {
      return null;
    }
    try {
      final baseW = boundary.size.width;
      _captureCount++;
      if (_viewCaptureWorks != true || _captureCount % 20 == 0) {
        _viewCaptureWorks = await _probeView(boundary, baseW);
      }
      if (_viewCaptureWorks != true) return null;
      final img = await boundary.toImage(pixelRatio: w / baseW);
      try {
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        return data?.buffer.asUint8List();
      } finally {
        img.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  /// 小图探测：判断平台视图是否真的被合成进 Flutter 层树可截。
  Future<bool> _probeView(RenderRepaintBoundary boundary, double baseW) async {
    try {
      final probe = await boundary.toImage(pixelRatio: 48 / baseW);
      try {
        final pd = await probe.toByteData(format: ui.ImageByteFormat.rawRgba);
        final px = pd?.buffer.asUint8List();
        if (px == null) return false;
        var firstColor = -1;
        var varied = false;
        for (var i = 0; i + 3 < px.length; i += 4 * 16) {
          if (px[i + 3] <= 10) continue; // 跳过透明像素
          final c = (px[i] << 24) |
              (px[i + 1] << 16) |
              (px[i + 2] << 8) |
              px[i + 3];
          if (firstColor == -1) {
            firstColor = c;
          } else if (c != firstColor) {
            varied = true;
            break;
          }
        }
        return firstColor != -1 && varied;
      } finally {
        probe.dispose();
      }
    } catch (_) {
      return false;
    }
  }

  /// JS 整页栅格化（回退方案）：把页面按 [w] x [h] 像素栅格化为 PNG base64 再解码。
  Future<Uint8List?> _captureViaJs(int w, int h, {String? background}) async {
    if (!_ready) return null;
    if (background != null) {
      await _created.runJavaScript(
          'try{window.__setBg && window.__setBg("$background");}catch(e){}');
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