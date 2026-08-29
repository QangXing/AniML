import 'package:flutter/material.dart';

import '../state/home_controller.dart';
import '../theme.dart';

/// 拍摄面板：设置拍摄时长/帧率，控制录制与输出 mp4。
class ShootPanel extends StatelessWidget {
  const ShootPanel({
    super.key,
    required this.controller,
    required this.onRecordCallback,
    required this.onShare,
  });

  final HomeController controller;
  final void Function() onRecordCallback;
  final Future<void> Function(String path) onShare;

  @override
  Widget build(BuildContext context) {
    final cfg = controller.config;
    return Glass(
      radius: 22,
      blur: 20,
      opacity: 0.92,
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.videocam_outlined,
                    size: 18, color: AppTheme.ink),
                SizedBox(width: 8),
                Text('拍摄',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink)),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Text('时长',
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.subInk)),
                Expanded(
                  child: Slider(
                    value: controller.shootSeconds.clamp(1.0, 30.0).toDouble(),
                    min: 1,
                    max: 30,
                    label: '${controller.shootSeconds.round()}s',
                    activeColor: AppTheme.ink,
                    inactiveColor: AppTheme.hairline,
                    onChanged: controller.isRecording
                        ? null
                        : (v) => (controller..shootSeconds = v).notifyListeners(),
                  ),
                ),
                Text('${controller.shootSeconds.round()} s',
                    style:
                        const TextStyle(color: AppTheme.subInk, fontSize: 12)),
              ],
            ),
            Row(
              children: [
                const Text('帧率',
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.subInk)),
                Expanded(
                  child: Slider(
                    value: controller.shootFps.toDouble().clamp(5, 60).toDouble(),
                    min: 5,
                    max: 60,
                    divisions: 11,
                    label: '${controller.shootFps}fps',
                    activeColor: AppTheme.ink,
                    inactiveColor: AppTheme.hairline,
                    onChanged: controller.isRecording
                        ? null
                        : (v) => (controller..shootFps = v.round()).notifyListeners(),
                  ),
                ),
                Text('${controller.shootFps} fps',
                    style:
                        const TextStyle(color: AppTheme.subInk, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Text('输出 ${cfg.pixelWidth} × ${cfg.pixelHeight}px',
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.subInk)),
            const SizedBox(height: 12),

            // 录制进度
            if (controller.isRecording) ...[
              LinearProgressIndicator(
                value: controller.recordProgress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
                color: const Color(0xFFE0313A),
                backgroundColor: AppTheme.hairline,
              ),
              const SizedBox(height: 6),
              Text(
                '录制中 ${(controller.recordProgress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFFE0313A)),
              ),
              const SizedBox(height: 12),
            ],

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRecordCallback,
                style: FilledButton.styleFrom(
                  backgroundColor: controller.isRecording
                      ? const Color(0xFFE0313A)
                      : AppTheme.ink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: controller.isRecording
                    ? const _PulseStop()
                    : const Icon(Icons.brightness_1, size: 18),
                label: Text(controller.isRecording ? '结束拍摄' : '开始拍摄',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: controller.isRecording
                  ? null
                  : () => onShare(''),
              child: const Text('拍摄完成后可分享 mp4',
                  style: TextStyle(fontSize: 11, color: AppTheme.subInk)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 录制时按钮里的“停止”方块：带节奏感的脉冲放大动画。
class _PulseStop extends StatefulWidget {
  const _PulseStop();

  @override
  State<_PulseStop> createState() => _PulseStopState();
}

class _PulseStopState extends State<_PulseStop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Transform.scale(
        scale: 1.0 + _c.value * 0.25,
        child: const Icon(Icons.stop, size: 18, color: Colors.white),
      ),
    );
  }
}