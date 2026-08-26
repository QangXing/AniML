import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/project_controller.dart';

/// 底部时间轴：播放控制 + 每条轨道上的条带 + 播放头。
class TimelinePanel extends ConsumerStatefulWidget {
  const TimelinePanel({super.key});

  @override
  ConsumerState<TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends ConsumerState<TimelinePanel> {
  static const double _pps = 40.0; // 每秒钟对应的像素
  double _scale = 1.0;

  double _px(double ms) => ms / 1000 * _pps * _scale;
  int _msAt(double px) => (px / (_pps * _scale) * 1000).round();

  @override
  Widget build(BuildContext context) {
    final proj = ref.watch(projectProvider);
    final totalMs = proj.timelineDuration.inMilliseconds;
    final contentW = _px(totalMs) + 80;
    final playheadX = _px(proj.playhead.inMilliseconds);

    return Container(
      height: 152,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xF01A1A20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A30)),
      ),
      child: Column(
        children: [
          _transportBar(proj),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Stack(
                children: [
                  SizedBox(
                    width: contentW,
                    child: Column(
                      children: [
                        _ruler(proj, contentW),
                        for (final layer in proj.layers)
                          _track(proj, layer.id, layer.name, contentW),
                        SizedBox(
                          height: 28,
                          width: contentW,
                          child: TextButton.icon(
                            onPressed: () => _addClip(proj),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('新建条带',
                                style: TextStyle(fontSize: 11)),
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: playheadX,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 1.5,
                      color: const Color(0xFFE53935),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _transportBar(ProjectController proj) {
    final playing = proj.playing;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(playing ? Icons.pause : Icons.play_arrow,
                color: const Color(0xFF2962FF)),
            onPressed: () => playing ? proj.pause() : proj.play(),
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: proj.stop,
          ),
          IconButton(
            icon: Icon(
              proj.previewLoop ? Icons.repeat : Icons.repeat_on,
              color: proj.previewLoop ? const Color(0xFF2962FF) : Colors.grey,
            ),
            onPressed: () {
              proj.previewLoop = !proj.previewLoop;
              proj.notifyListeners();
            },
          ),
          const SizedBox(width: 8),
          Text(
            '${_fmt(proj.playhead)}/${_fmt(proj.timelineDuration)}',
            style: const TextStyle(
                fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
          ),
          const Spacer(),
          Text('时长',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          SizedBox(
            width: 90,
            child: TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  isDense: true, border: OutlineInputBorder(), hintText: '秒'),
              onSubmitted: (v) {
                final sec = double.tryParse(v);
                if (sec != null && sec > 0) {
                  proj.setTimelineDuration(
                      Duration(milliseconds: (sec * 1000).round()));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruler(ProjectController proj, double contentW) {
    final totalSec = proj.timelineDuration.inMilliseconds / 1000;
    return SizedBox(
      height: 22,
      width: contentW,
      child: GestureDetector(
        onTapDown: (d) => proj.seek(Duration(milliseconds: _msAt(d.localPosition.dx))),
        child: CustomPaint(painter: _RulerPainter(totalSec: totalSec, pps: _pps * _scale)),
      ),
    );
  }

  Widget _track(
      ProjectController proj, String layerId, String name, double contentW) {
    final clips = proj.clipsFor(layerId);
    return SizedBox(
      height: 30,
      width: contentW,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.15),
              border: const Border(bottom: BorderSide(color: Color(0xFF2A2A30), width: 1)),
            ),
          ),
          Positioned(
            left: 4,
            top: 7,
            child: Text(name,
                style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ),
          for (final clip in clips) _clipWidget(proj, clip),
        ],
      ),
    );
  }

  Widget _clipWidget(ProjectController proj, ClipRef clip) {
    final left = _px(clip.startMs);
    final width = _px(clip.endMs) - _px(clip.startMs);
    return Positioned(
      left: left,
      top: 4,
      child: GestureDetector(
        onHorizontalDragUpdate: (d) {
          final deltaMs = _msAt(d.delta.dx);
          proj.moveClip(clip.id, deltaMs);
        },
        child: Container(
          width: width.clamp(8, double.infinity),
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF2962FF).withOpacity(0.7),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              _resizeHandle(proj, clip, left: true),
              const Expanded(
                  child: Center(
                      child: Text('▤',
                          style: TextStyle(fontSize: 11, color: Colors.white)))),
              _resizeHandle(proj, clip, left: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resizeHandle(ProjectController proj, ClipRef clip, {required bool left}) {
    return GestureDetector(
      dragStartBehavior: DragStartBehavior.down,
      onHorizontalDragUpdate: (d) {
        final deltaMs = _msAt(d.delta.dx);
        if (left) {
          final newStart = (clip.startMs + deltaMs).clamp(0, clip.endMs - 1);
          proj.resizeClip(clip.id, startMs: newStart);
        } else {
          final newEnd = (clip.endMs + deltaMs).clamp(clip.startMs + 1,
              proj.timelineDuration.inMilliseconds);
          proj.resizeClip(clip.id, endMs: newEnd);
        }
      },
      child: Container(width: 10, height: 22, color: Colors.transparent),
    );
  }

  void _addClip(ProjectController proj) {
    if (proj.activeLayerId == null) return;
    var start = 0;
    var found = false;
    for (final c in proj.clipsFor(proj.activeLayerId!)) {
      if (c.startMs >= start && c.startMs < 5000) {
        start = c.endMs;
        found = true;
      }
    }
    if (!found && proj.clipsFor(proj.activeLayerId!).isEmpty) {
      proj.addClip(proj.activeLayerId!, 0, 1000);
      return;
    }
    proj.addClip(proj.activeLayerId!, start, start + 1000);
  }
}

String _fmt(Duration d) {
  final s = d.inMilliseconds / 1000;
  return s.toStringAsFixed(1) + 's';
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({required this.totalSec, required this.pps});
  final double totalSec;
  final double pps;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3A3A42)
      ..strokeWidth = 1;
    final textFinder = TextPainter(
      textDirection: TextDirection.ltr,
    );
    for (var s = 0; s <= totalSec; s += 1) {
      final x = s * pps;
      canvas.drawLine(Offset(x, 6), Offset(x, 22), paint);
      if (s % 5 == 0 || pps > 30) {
        textFinder.text = TextSpan(
          text: '${s}s',
          style: const TextStyle(color: Colors.white54, fontSize: 9),
        );
        textFinder.layout();
        textFinder.paint(canvas, Offset(x + 2, 0));
      }
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.totalSec != totalSec || old.pps != pps;
}