import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/recording_engine.dart';
import '../../state/render_controller.dart';
import 'press_scale.dart';

/// 拍摄模式控制面板：设置时长/帧率，抓取渲染区实时像素并合成 MP4。
class ShootPanel extends StatefulWidget {
  const ShootPanel({
    super.key,
    required this.controller,
    required this.producer,
  });

  final RenderController controller;
  final FrameProducer producer;

  @override
  State<ShootPanel> createState() => _ShootPanelState();
}

class _ShootPanelState extends State<ShootPanel> {
  late RecordingEngine _engine;
  double _duration = 6;
  double _fps = 12;

  bool _recording = false;
  Uint8List? _preview;
  int _frames = 0;
  int _total = 0;
  String? _resultPath;
  String? _error;

  RenderController get rc => widget.controller;

  @override
  void initState() {
    super.initState();
    _engine = RecordingEngine(producer: widget.producer, fps: _fps);
    _engine.onProgress = _onProgress;
    _engine.onComplete = _onComplete;
  }

  void _onProgress(int frame, int total) {
    if (mounted) {
      setState(() {
        _frames = frame;
        _total = total;
      });
      _refreshPreview();
    }
  }

  Future<void> _refreshPreview() async {
    final f = await widget.producer();
    if (f != null && mounted) setState(() => _preview = f);
  }

  void _onComplete(String? path, String? error) {
    if (!mounted) return;
    setState(() {
      _recording = false;
      _resultPath = path;
      _error = error;
    });
    rc.setRecording(false);
  }

  Future<void> _start() async {
    setState(() {
      _recording = true;
      _resultPath = null;
      _error = null;
      _frames = 0;
      _total = (_duration * _fps).round();
    });
    rc.setRecording(true);
    await _engine.start(_duration.round());
  }

  Future<void> _stop() async {
    await _engine.stop(finish: true);
  }

  Future<void> _cancel() async {
    await _engine.cancel();
    setState(() {
      _recording = false;
    });
    rc.setRecording(false);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = rc.config;
    return Positioned(
      left: 20,
      right: 340,
      bottom: 20,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 16),
              child: child,
            ),
          ),
          child: GlassBackdrop(
          radius: 22,
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: AppTheme.glassColor,
              borderRadius: BorderRadius.all(Radius.circular(22)),
              border: Border.fromBorderSide(BorderSide(color: AppTheme.glassBorder)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('拍摄 · 输出 ${cfg.outputW}×${cfg.outputH}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                if (_preview != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: Image.memory(
                        _preview!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                _SliderRow(
                  label: '时长',
                  suffix: '${_duration.round()} 秒',
                  value: _duration,
                  min: 1,
                  max: 30,
                  onChanged: (v) => setState(() => _duration = v),
                ),
                _SliderRow(
                  label: '帧率',
                  suffix: '${_fps.round()} fps',
                  value: _fps,
                  min: 6,
                  max: 24,
                  onChanged: (v) {
                    setState(() => _fps = v);
                    _engine = RecordingEngine(producer: widget.producer, fps: _fps); // 替换帧率
                  },
                ),
                const SizedBox(height: 8),
                if (_recording)
                  _ProgressBar(current: _frames, total: _total),
                if (_resultPath != null) ...[
                  const SizedBox(height: 8),
                  Text('已保存：$_resultPath',
                      style: const TextStyle(fontSize: 12, color: AppTheme.accent)),
                  const SizedBox(height: 8),
                  PressScale(
                    child: FilledButton.tonalIcon(
                      onPressed: () => setState(() => _resultPath = null),
                      icon: const Icon(Icons.replay, size: 18),
                      label: const Text('再拍一段'),
                    ),
                  ),
                ] else if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text('失败：$_error',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFD9534F))),
                  const SizedBox(height: 8),
                  PressScale(
                    child: FilledButton.tonalIcon(
                      onPressed: () => setState(() => _error = null),
                      icon: const Icon(Icons.replay, size: 18),
                      label: const Text('重试'),
                    ),
                  ),
                ] else
                  Align(
                    alignment: Alignment.centerRight,
                    child: _recording
                        ? PressScale(
                            pressedScale: 0.94,
                            child: FilledButton.icon(
                              onPressed: _stop,
                              icon: const Icon(Icons.stop, size: 20, color: Colors.white),
                              label: const Text('停止并合成'),
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB84A4A)),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_error != null)
                                PressScale(
                                  pressedScale: 0.94,
                                  child: TextButton(
                                    onPressed: () => setState(() => _error = null),
                                    child: const Text('重试'),
                                  ),
                                ),
                              PressScale(
                                pressedScale: 0.94,
                                child: FilledButton.icon(
                                  onPressed: _start,
                                  icon: const Icon(Icons.videocam, size: 20, color: Colors.white),
                                  label: const Text('开始拍摄'),
                                  style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
                                ),
                              ),
                            ],
                          ),
                  ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.suffix,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String suffix;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 30, child: Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            activeColor: AppTheme.accent,
            inactiveColor: const Color(0x228A9099),
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 44, child: Text(suffix, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final p = total == 0 ? 0.0 : (current / total).clamp(0.0, 1.0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: p, minHeight: 8, backgroundColor: const Color(0x228A9099), color: AppTheme.accent),
        ),
        const SizedBox(height: 4),
        Text('已采 $current / $total 帧', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}