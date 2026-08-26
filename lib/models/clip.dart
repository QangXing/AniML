/// 时间轴条带，表示某个层在 [start, end] 时间段内可见/活跃。
class Clip {
  Clip({
    required this.id,
    required this.layerId,
    this.start = const Duration(seconds: 0),
    this.end = const Duration(seconds: 5),
  });

  final String id;
  final String layerId;
  Duration start;
  Duration end;

  Duration get duration => end - start;

  bool operator ==(Object other) => other is Clip && other.id == id;

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() => {
        'id': id,
        'layerId': layerId,
        'start': start.inMilliseconds,
        'end': end.inMilliseconds,
      };

  factory Clip.fromJson(Map<String, dynamic> json) => Clip(
        id: json['id'] as String,
        layerId: json['layerId'] as String,
        start: Duration(milliseconds: (json['start'] ?? 0) as int),
        end: Duration(milliseconds: (json['end'] ?? 5000) as int),
      );
}