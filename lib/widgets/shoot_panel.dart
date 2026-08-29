import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                const SizedBox(width: 8),
                Expanded(
                  child: _NumInput(
                    text: controller.shootSeconds.round().toString(),
                    enabled: !controller.isRecording,
                    decimal: false,
                    onChanged: (s) {
                      final v = double.tryParse(s);
                      if (v != null) controller.setShootSeconds(v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Text('秒',
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.subInk)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('帧率',
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.subInk)),
                const SizedBox(width: 8),
                Expanded(
                  child: _NumInput(
                    text: controller.shootFps.toString(),
                    enabled: !controller.isRecording,
                    decimal: false,
                    onChanged: (s) {
                      final v = int.tryParse(s);
                      if (v != null) controller.setShootFps(v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Text('fps',
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.subInk)),
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

/// 可写入的数字输入框（替代拉条）：输入即实时回调解析出的数值。
class _NumInput extends StatefulWidget {
  const _NumInput({
    required this.text,
    required this.enabled,
    required this.decimal,
    required this.onChanged,
  });

  final String text;
  final bool enabled;
  final bool decimal;
  final ValueChanged<String> onChanged;

  @override
  State<_NumInput> createState() => _NumInputState();
}

class _NumInputState extends State<_NumInput> {
  late final TextEditingController _c =
      TextEditingController(text: widget.text);

  @override
  void didUpdateWidget(covariant _NumInput old) {
    super.didUpdateWidget(old);
    // 仅在未聚焦时同步外部变化，避免打断正在输入的内容。
    if (!_c.selection.isValid && widget.text != _c.text) {
      _c.text = widget.text;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      enabled: widget.enabled,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
            widget.decimal ? RegExp(r'[\d.]') : RegExp(r'\d')),
      ],
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14, color: AppTheme.ink),
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.subInk),
        ),
      ),
      // 输入即生效：不用等回车/收起键盘，拍摄时直接取到设置值。
      onChanged: widget.onChanged,
      onSubmitted: widget.onChanged,
    );
  }
}