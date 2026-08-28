import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// 当前绝对变换（控制器状态 + 手势几何快照）。
class FreeTransformState {
  const FreeTransformState({
    required this.offset,
    required this.scale,
    required this.rotation,
    this.center = Offset.zero,
    this.span = 0,
    this.angle = 0,
    this.isSingle = false,
  });

  /// 控制器中的绝对平移 / 缩放 / 旋转。
  final Offset offset;
  final double scale;
  final double rotation;

  /// 手势几何：质心、两指跨度、两指夹角。
  final Offset center;
  final double span;
  final double angle;

  /// 当前是否仅单指。
  final bool isSingle;
}

/// 2D 自由变换手势识别器。
///
/// 单指：平移；双指：缩放 + 质心平移（旋转不再由手势驱动）。
/// [readBase] 在每次手势开始时读取当前绝对变换，作为累计基准。
class FreeTransformRecognizer extends OneSequenceGestureRecognizer {
  FreeTransformRecognizer({
    required this.readBase,
    required this.onUpdate,
  });

  /// 读取手势开始时刻的绝对变换（控制器当前状态）。
  final FreeTransformState Function() readBase;

  /// 手势过程中的绝对变换（已叠加当前手势增量）。
  final ValueChanged<FreeTransformState> onUpdate;

  final Map<int, Offset> _pointers = {};
  FreeTransformState? _snap; // 手势开始时几何快照 + 绝对基准

  bool get hasMultiple => _pointers.length >= 2;

  @override
  void addPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer);
    _pointers[event.pointer] = event.position;
    _snapshot();
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent && _pointers.containsKey(event.pointer)) {
      _pointers[event.pointer] = event.position;
      resolve(GestureDisposition.accepted);
      _emit();
    }
  }

  void _snapshot() {
    if (_snap != null) return;
    if (_pointers.isEmpty) return;
    final base = readBase();
    final pts = _pointers.values.toList();
    if (pts.length == 1) {
      _snap = FreeTransformState(
        offset: base.offset,
        scale: base.scale,
        rotation: base.rotation,
        center: pts.first,
        span: 1,
        angle: 0,
        isSingle: true,
      );
    } else {
      _snap = FreeTransformState(
        offset: base.offset,
        scale: base.scale,
        rotation: base.rotation,
        center: _centroid(pts),
        span: (pts[0] - pts[1]).distance,
        angle: (pts[0] - pts[1]).direction,
      );
    }
  }

  void _emit() {
    final snap = _snap;
    if (snap == null) return;
    final pts = _pointers.values.toList();
    if (pts.isEmpty) return;

    if (pts.length == 1) {
      final cur = pts.first;
      final delta = cur - snap.center;
      onUpdate(FreeTransformState(
        offset: snap.offset + delta,
        scale: snap.scale,
        rotation: snap.rotation,
      ));
      return;
    }

    final center = _centroid(pts);
    final span = (pts[0] - pts[1]).distance;
    final angle = (pts[0] - pts[1]).direction;
    // 由于基准跨度为两指初始距离，这里用相对增量换算缩放因子。
    // 旋转不再由手势驱动（留待右侧旋转滑杆精确控制）。
    final scaleFactor = (span) / (snap.span == 0 ? 1 : snap.span);

    FreeTransformState out;
    if (snap.isSingle) {
      // 从单指切到双指：把当前绝对变换作为新基准
      final base = readBase();
      out = FreeTransformState(
        offset: base.offset + (center - snap.center),
        scale: base.scale,
        rotation: base.rotation,
        center: center,
        span: span,
        angle: angle,
      );
      _snap = FreeTransformState(
        offset: out.offset,
        scale: out.scale,
        rotation: out.rotation,
        center: center,
        span: span,
        angle: angle,
      );
      onUpdate(out);
      return;
    }

    out = FreeTransformState(
      offset: snap.offset + (center - snap.center),
      scale: snap.scale * scaleFactor,
      rotation: snap.rotation,
    );
    _snap = FreeTransformState(
      offset: out.offset,
      scale: out.scale,
      rotation: out.rotation,
      center: center,
      span: span,
      angle: angle,
    );
    onUpdate(out);
  }

  Offset _centroid(List<Offset> pts) {
    Offset s = Offset.zero;
    for (final p in pts) {
      s = s + p;
    }
    return Offset(s.dx / pts.length, s.dy / pts.length);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointers.remove(pointer);
    _snap = null;
    stopTrackingPointer(pointer);
  }

  @override
  void dispose() {
    _pointers.clear();
    _snap = null;
    super.dispose();
  }

  @override
  String get debugDescription => 'free transform';
}