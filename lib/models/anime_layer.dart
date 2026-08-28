/// 一个 HTML 层。
class AniLayer {
  AniLayer({
    required this.id,
    required this.name,
    required this.index,
    this.visible = true,
    this.locked = false,
    this.opacity = 1.0,
    this.blendMode = 'normal',
    required this.source,
    required this.assetPath,
  });

  /// 层 ID（UUID）。
  final String id;

  /// 展示名。
  String name;

  /// 层号，越小越先渲染（在底层）。
  int index;

  bool visible;
  bool locked;
  double opacity;
  String blendMode;

  /// 该层 HTML 的源码（可直接加载的字符串）。
  String source;

  /// 资源所在目录（用于解析相对资源路径）。
  String? assetPath;

  AniLayer copyWith({String? name, int? index, bool? visible, bool? locked, double? opacity, String? blendMode, String? source}) {
    return AniLayer(
      id: id,
      name: name ?? this.name,
      index: index ?? this.index,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      opacity: opacity ?? this.opacity,
      blendMode: blendMode ?? this.blendMode,
      source: source ?? this.source,
      assetPath: assetPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'index': index,
        'visible': visible,
        'locked': locked,
        'opacity': opacity,
        'blendMode': blendMode,
        'source': source,
        'assetPath': assetPath,
      };

  factory AniLayer.fromJson(Map<String, dynamic> json) => AniLayer(
        id: json['id'] as String,
        name: json['name'] as String? ?? '层',
        index: (json['index'] ?? 0) as int,
        visible: (json['visible'] ?? true) as bool,
        locked: (json['locked'] ?? false) as bool,
        opacity: (json['opacity'] ?? 1.0).toDouble(),
        blendMode: json['blendMode'] as String? ?? 'normal',
        source: json['source'] as String? ?? '<html><body></body></html>',
        assetPath: json['assetPath'] as String?,
      );
}