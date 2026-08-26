/// 项目内引用的资源条目。
class AssetItem {
  AssetItem({
    required this.id,
    required this.type,
    required this.path,
  });

  final String id;
  final String type; // image | font | script | style
  final String path;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'path': path,
      };

  factory AssetItem.fromJson(Map<String, dynamic> json) => AssetItem(
        id: json['id'] as String,
        type: json['type'] as String,
        path: json['path'] as String,
      );
}