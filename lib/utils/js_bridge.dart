/// 与 WebView 内注入的 window._AniML 相关的常量常量与收发的消息名。
library;

class JsBridge {
  JsBridge._();

  /// WebView 中注入的全局对象名。
  static const String globalObject = "window._AniML";

  /// Flutter -> JS 方法调用。
  static const String jsSelectElement = "selectElement";
  static const String jsGetElementStyles = "getElementStyles";
  static const String jsSetElementStyles = "setElementStyles";
  static const String jsSetLayerVisible = "setLayerVisible";
  static const String jsSetLayerZIndex = "setLayerZIndex";

  /// JS -> Flutter 事件消息名。
  static const String channelName = "AniMLBridge";

  /// 注入到每个层文档的基础脚本。
  static const String bootstrap = r'''
window._AniML = {
  _selected: null,
  selectElement: function(selector) {
    this._selected = document.querySelector(selector);
    this._drawSelection();
    return this._selected ? this._selected.outerHTML : null;
  },
  getElementStyles: function() {
    if (!this._selected) return null;
    var s = this._selected;
    var r = s.getBoundingClientRect();
    return {
      left: r.left, top: r.top, width: r.width, height: r.height,
      opacity: getComputedStyle(s).opacity,
      rotate: 0, scale: 1
    };
  },
  setElementStyles: function(styles) {
    if (!this._selected) return;
    if (styles.left !== undefined) this._selected.style.left = styles.left + 'px';
    if (styles.top !== undefined) this._selected.style.top = styles.top + 'px';
    if (styles.width !== undefined) this._selected.style.width = styles.width + 'px';
    if (styles.height !== undefined) this._selected.style.height = styles.height + 'px';
    if (styles.opacity !== undefined) this._selected.style.opacity = styles.opacity;
  },
  _drawSelection: function() {
    var old = document.getElementById('__animl_selection__');
    if (old) old.remove();
    if (!this._selected) return;
    var r = this._selected.getBoundingClientRect();
    var box = document.createElement('div');
    box.id = '__animl_selection__';
    box.style.cssText = 'position:fixed;left:'+r.left+'px;top:'+r.top+'px;' +
      'width:'+r.width+'px;height:'+r.height+'px;z-index:999999;' +
      'box-shadow:0 0 0 1px #2962FF, inset 0 0 0 1px #2962FF;pointer-events:none;';
    document.body.appendChild(box);
  },
  setLayerVisible: function(visible) {
    document.documentElement.style.display = visible ? 'block' : 'none';
    window.flutter_inappwebview.callHandler('setLayerVisible', [visible]);
  }
};
''';
}