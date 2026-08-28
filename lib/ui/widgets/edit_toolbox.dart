import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/presets.dart';
import '../../models/render_config.dart';
import '../../state/render_controller.dart';
import 'press_scale.dart';

/// 更改模式下的右侧可拉取工具箱：调整渲染区长宽、比例、输出像素。
class EditToolbox extends StatefulWidget {
  const EditToolbox({
    super.key,
    required this.controller,
    required this.visible,
    this.onClose,
  });

  final RenderController controller;
  final bool visible;
  final VoidCallback? onClose;

  @override
  State<EditToolbox> createState() => _EditToolboxState();
}

class _EditToolboxState extends State<EditToolbox> {
  late final TextEditingController _wCtrl;
  late final TextEditingController _hCtrl;

  @override
  void initState() {
    super.initState();
    final cfg = widget.controller.config;
    _wCtrl = TextEditingController(text: cfg.outputW.toString());
    _hCtrl = TextEditingController(text: cfg.outputH.toString());
  }

  @override
  void dispose() {
    _wCtrl.dispose();
    _hCtrl.dispose();
    super.dispose();
  }

  RenderConfig get cfg => widget.controller.config;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      right: widget.visible ? 20 : -340,
      top: 20,
      bottom: 20,
      width: 300,
      child: GlassBackdrop(
        radius: 22,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          decoration: const BoxDecoration(
            color: AppTheme.glassColor,
            borderRadius: BorderRadius.all(Radius.circular(22)),
            border: Border.fromBorderSide(BorderSide(color: AppTheme.glassBorder)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('工具箱',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const Spacer(),
                  PressScale(
                    pressedScale: 0.85,
                    child: IconButton(
                      tooltip: '收起工具箱',
                      icon: const Icon(Icons.keyboard_arrow_right, color: AppTheme.pureGrey),
                      onPressed: () {
                        if (widget.visible) widget.onClose?.call();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('渲染区 · 屏幕',
                          hint: '宽 / 高（逻辑单位，决定窗口大小与比例）'),
                      const SizedBox(height: 4),
                      _LockAspectSwitch(
                        value: cfg.lockAspect,
                        onChanged: widget.controller.setLockAspect,
                      ),
                      _RangeStepRow(
                        label: '宽',
                        value: cfg.displayW.round(),
                        onChanged: (v) =>
                            widget.controller.setDisplaySize(v.toDouble(), cfg.displayH),
                      ),
                      _RangeStepRow(
                        label: '高',
                        value: cfg.displayH.round(),
                        onChanged: (v) => widget.controller.setDisplayHeight(v.toDouble()),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '比例  ${cfg.displayW.toStringAsFixed(0)} : ${cfg.displayH.toStringAsFixed(0)}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      const _SectionTitle('比例预设'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in kAspectPresets)
                            _Chip(
                              label: p.label,
                              onTap: () => widget.controller.applyAspectPreset(p.w, p.h),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _SectionTitle('输出像素'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        key: ValueKey('preset-${cfg.outputW}x${cfg.outputH}'),
                        initialValue: _presetIndex(),
                        decoration: _fieldDecoration('分辨率预设'),
                        items: [
                          for (var i = 0; i < kOutputPresets.length; i++)
                            DropdownMenuItem(value: i, child: Text(kOutputPresets[i].label)),
                          const DropdownMenuItem(value: -1, child: Text('自定义')),
                        ],
                        onChanged: (idx) {
                          if (idx == null || idx < 0) return;
                          final p = kOutputPresets[idx];
                          widget.controller.setOutputSize(p.w, p.h);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _wCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 13),
                              decoration: _fieldDecoration('像素宽'),
                              onSubmitted: (v) =>
                                  widget.controller.setOutputSize(int.tryParse(v) ?? cfg.outputW, cfg.outputH),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _hCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 13),
                              decoration: _fieldDecoration('像素高'),
                              onSubmitted: (v) =>
                                  widget.controller.setOutputSize(cfg.outputW, int.tryParse(v) ?? cfg.outputH),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '最终输出 ${cfg.outputW}×${cfg.outputH} px',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      ConstrainedBox(
                        constraints: const BoxConstraints.tightFor(width: double.infinity),
                        child: PressScale(
                          child: FilledButton.tonalIcon(
                            onPressed: () {
                              final w = int.tryParse(_wCtrl.text) ?? cfg.outputW;
                              final h = int.tryParse(_hCtrl.text) ?? cfg.outputH;
                              widget.controller.setOutputSize(w, h);
                            },
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('应用像素尺寸'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _presetIndex() {
    for (var i = 0; i < kOutputPresets.length; i++) {
      if (kOutputPresets[i].w == cfg.outputW && kOutputPresets[i].h == cfg.outputH) return i;
    }
    return -1;
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0x228A9099))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0x228A9099))),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.hint});
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint!, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ],
    );
  }
}

class _LockAspectSwitch extends StatelessWidget {
  const _LockAspectSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('锁定长宽比', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const Spacer(),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.accent,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

class _RangeStepRow extends StatelessWidget {
  const _RangeStepRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 26,
            child: Text(label,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
        Expanded(
          child: Slider(
            value: value.clamp(120, 900).toDouble(),
            min: 120,
            max: 900,
            activeColor: AppTheme.accent,
            inactiveColor: const Color(0x228A9099),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text('$value',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      pressedScale: 0.9,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x228A9099)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
        ),
      ),
    );
  }
}