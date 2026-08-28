import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/editor_mode.dart';

/// 左下角三功能切换栏：搜索 / 更改 / 拍摄。
class ModeControlBar extends StatelessWidget {
  const ModeControlBar({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final EditorMode mode;
  final ValueChanged<EditorMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassBackdrop(
      radius: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: const BoxDecoration(
          color: AppTheme.glassColor,
          borderRadius: BorderRadius.all(Radius.circular(30)),
          border: Border.fromBorderSide(BorderSide(color: AppTheme.glassBorder)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeButton(
              icon: Icons.search,
              label: '搜索',
              active: mode == EditorMode.search,
              onTap: () => onChanged(EditorMode.search),
            ),
            _ModeButton(
              icon: Icons.edit,
              label: '更改',
              active: mode == EditorMode.edit,
              onTap: () => onChanged(EditorMode.edit),
            ),
            _ModeButton(
              icon: Icons.videocam,
              label: '拍摄',
              active: mode == EditorMode.shoot,
              onTap: () => onChanged(EditorMode.shoot),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.accent : AppTheme.pureGrey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: active ? AppTheme.accent : AppTheme.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}