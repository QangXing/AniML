import 'dart:convert';

import '../controllers/project_controller.dart';
import '../models/anime_layer.dart';

/// 将多个 HTML 层编译为单一自包含 HTML。
class HtmlCompiler {
  HtmlCompiler._();

  /// 编译：把所有层按 z-index 合成到同一文档；时间轴控制每层显隐。
  static String compile(ProjectController c, {double? width, double? height}) {
    final w = width ?? c.canvas.width;
    final h = height ?? c.canvas.height;
    final layers = List<AniLayer>.of(c.layers)..sort((a, b) => a.index.compareTo(b.index));

    final bg = c.canvas.backgroundColor.value;
    final bgHex = '#${bg.toRadixString(16).padLeft(8, '0').substring(2)}';

    final buff = StringBuffer();
    buff.writeln('<!DOCTYPE html>');
    buff.writeln('<html lang="zh"><head><meta charset="utf-8">');
    buff.writeln('<meta name="viewport" content="width=$w, height=$h">');
    buff.writeln('<title>${c.timelineDuration.inMilliseconds}ms</title>');
    buff.writeln('''<style>
    html,body{margin:0;padding:0;width:${w}px;height:${h}px;background:$bgHex;overflow:hidden}
    .as-layer{position:absolute;left:0;top:0;width:${w}px;height:${h}px;border:0}
    </style>''');
    buff.writeln('</head><body>');

    for (final layer in layers) {
      if (!layer.visible) continue;
      final idx = layer.index;
      final keyName = 'layersVisible_${idx}';
      _writeLayerMarkup(buff, layer, keyName, w, h);
      _writeLayerKeyframes(buff, keyName, layer, c);
    }

    buff.writeln('</body></html>');
    return buff.toString();
  }

  static void _writeLayerMarkup(StringBuffer buff, AniLayer layer, String keyName,
      double w, double h) {
    final iframe = '''<iframe class="as-layer" style="z-index:${layer.index}"
      title="${_esc(layer.name)}" srcdoc="${_escAttr(layer.source)}"></iframe>''';
    buff.writeln('<div class="as-layer" style="z-index:${layer.index};animation:'
        '$keyName ${_toMs(0)}ms linear infinite">$iframe</div>');
  }

  /// 根据条带为某层生成显隐关键帧。
  static void _writeLayerKeyframes(StringBuffer buff, String keyName, AniLayer layer,
      ProjectController c) {
    final total = c.timelineDuration.inMilliseconds <= 0 ? 1 : c.timelineDuration.inMilliseconds;
    final clips = c.clipsFor(layer.id);
    // 归一化的可见区间（0..1），带 80ms 淡入淡出。
    final visible = <List<double>>[];
    for (final clip in clips) {
      double s = (clip.startMs / total).clamp(0.0, 1.0);
      double e = (clip.endMs / total).clamp(0.0, 1.0);
      if (e <= s) continue;
      const fade = 0.01;
      visible.add([s, e, fade]);
    }

    buff.write('@keyframes $keyName {');
    if (visible.isEmpty) {
      buff.write('0%{opacity:0}99%{opacity:0}100%{opacity:0}');
    } else {
      var cursor = 0.0;
      for (final seg in visible) {
        final s = seg[0], e = seg[1], fade = seg[2];
        if (s > cursor) {
          buff.write('${_pct(cursor)}%{opacity:0}${_pct(s)}%{opacity:0}');
        }
        buff.write('${_pct(s)}%{opacity:1}');
        if (e + fade <= 1.0) {
          buff.write('${_pct(e)}%{opacity:1}${_pct(e + fade)}%{opacity:0}');
        } else {
          buff.write('${_pct(e)}%{opacity:1}100%{opacity:0}');
        }
        cursor = e + fade;
      }
    }
    buff.writeln('}');
  }

  static String _pct(double v) {
    final p = (v.clamp(0.0, 1.0) * 10000).round() / 100;
    return p.toStringAsFixed(2);
  }

  static String _toMs(int ms) => ms.toString();

  static String _esc(String s) =>
      const HtmlEscape().convert(s.replaceAll(RegExp(r'\s+'), ' '));

  static String _escAttr(String s) {
    // srcdoc 属性需要把引号实体化，避免破坏外层属性。
    return _esc(s).replaceAll('"', '&quot;').replaceAll("'", '&#39;');
  }
}