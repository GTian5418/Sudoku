import 'package:flutter/material.dart';

import '../logic/game_controller.dart';
import 'board_widget.dart';

/// 底部数字键盘 + 功能按钮 + 颜色面板。
class NumberPad extends StatelessWidget {
  const NumberPad({super.key, required this.controller});

  final GameController controller;

  int _placed(int digit) {
    var count = 0;
    for (final row in controller.board) {
      for (final value in row) {
        if (value == digit) count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Column(
          children: [
            Row(
              children: [
                for (int digit = 1; digit <= 9; digit++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _DigitButton(
                        digit: digit,
                        remaining: 9 - _placed(digit),
                        isActive: controller.activeDigit == digit,
                        onTap: () => controller.padDigit(digit),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: controller.notesMode ? Icons.edit_off : Icons.edit,
                    label: '笔记',
                    highlighted: controller.notesMode,
                    onTap: controller.toggleNotesMode,
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.backspace_outlined,
                    label: '擦除',
                    onTap: controller.erase,
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.lightbulb_outline,
                    label: '提示',
                    onTap: controller.hint,
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.save_outlined,
                    label: '备份',
                    onTap: controller.backup,
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.restore,
                    label: '恢复',
                    enabled: controller.hasBackup,
                    onTap: controller.hasBackup ? controller.restore : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ColorPalette(controller: controller),
          ],
        );
      },
    );
  }
}

/// HoDoKu 风格颜色面板：5 色对 + 清色按钮。
class _ColorPalette extends StatelessWidget {
  const _ColorPalette({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final active = controller.activeColor;
    return Row(
      children: [
        // 5 个颜色对按钮，每个显示正/反两色。
        for (int pair = 0; pair < 5; pair++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _ColorPairButton(
                primaryColor: kCellColorPalette[pair],
                alternateColor: kCellColorPalette[pair + 5],
                primaryActive: active == pair + 1,
                alternateActive: active == pair + 6,
                onPrimary: () => controller.enterColorMode(pair + 1),
                onAlternate: () => controller.enterColorMode(pair + 6),
              ),
            ),
          ),
        const SizedBox(width: 4),
        // 清色按钮。
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _ActionButton(
              icon: Icons.format_color_reset_outlined,
              label: '清色',
              onTap: controller.clearAllColors,
            ),
          ),
        ),
        // 退出着色模式按钮。
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _ActionButton(
              icon: Icons.pan_tool_outlined,
              label: '退出',
              highlighted: active != null,
              onTap: active != null ? controller.exitColorMode : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorPairButton extends StatelessWidget {
  const _ColorPairButton({
    required this.primaryColor,
    required this.alternateColor,
    required this.primaryActive,
    required this.alternateActive,
    required this.onPrimary,
    required this.onAlternate,
  });

  final Color primaryColor;
  final Color alternateColor;
  final bool primaryActive;
  final bool alternateActive;
  final VoidCallback onPrimary;
  final VoidCallback onAlternate;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPrimary,
        onLongPress: onAlternate,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _swatch(primaryColor, primaryActive),
              const SizedBox(width: 3),
              _swatch(alternateColor, alternateActive),
            ],
          ),
        ),
      ),
    );
  }

  Widget _swatch(Color color, bool active) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? Colors.black : Colors.black26,
          width: active ? 2.5 : 1,
        ),
      ),
    );
  }
}

class _DigitButton extends StatelessWidget {
  const _DigitButton({
    required this.digit,
    required this.remaining,
    required this.onTap,
    this.isActive = false,
  });

  final int digit;
  final int remaining;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: isActive ? scheme.primaryContainer : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Text(
                '$digit',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: isActive ? scheme.onPrimaryContainer : Colors.black,
                ),
              ),
              Text(
                remaining > 0 ? '$remaining' : '',
                style: TextStyle(fontSize: 11, color: scheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlighted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = !enabled || onTap == null;
    final contentColor = disabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : highlighted
            ? scheme.onPrimaryContainer
            : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: highlighted ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Icon(icon, size: 20, color: contentColor),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: contentColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
