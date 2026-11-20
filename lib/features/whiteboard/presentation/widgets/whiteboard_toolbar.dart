import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'whiteboard_controller.dart';

/// Pen / eraser / pan tool switch, undo/redo/clear and zoom controls — a
/// dedicated pan tool (rather than relying on pinch gestures) is what keeps
/// a two-finger scroll from ever being misread as a stroke, and vice versa.
class WhiteboardToolbar extends StatelessWidget {
  const WhiteboardToolbar({super.key, required this.controller});

  final WhiteboardController controller;

  static const _colors = [Colors.black, Colors.red, Colors.blue];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Material(
          color: AppColors.surface,
          elevation: 2,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                _ToolButton(
                  icon: Icons.edit_outlined,
                  selected: controller.tool == WhiteboardTool.pen,
                  onTap: () => controller.setTool(WhiteboardTool.pen),
                  tooltip: 'قلم',
                ),
                _ToolButton(
                  icon: Icons.auto_fix_normal_outlined,
                  selected: controller.tool == WhiteboardTool.eraser,
                  onTap: () => controller.setTool(WhiteboardTool.eraser),
                  tooltip: 'ممحاة',
                ),
                _ToolButton(
                  icon: Icons.pan_tool_outlined,
                  selected: controller.tool == WhiteboardTool.pan,
                  onTap: () => controller.setTool(WhiteboardTool.pan),
                  tooltip: 'تحريك الصفحة',
                ),
                const SizedBox(width: 8),
                for (final c in _colors)
                  GestureDetector(
                    onTap: () => controller.setPenColor(c),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: controller.penColor.toARGB32() == c.toARGB32()
                              ? AppColors.accent
                              : AppColors.border,
                          width: controller.penColor.toARGB32() == c.toARGB32()
                              ? 3
                              : 1,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.zoom_out),
                  onPressed: () => controller.zoomBy(0.9),
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_in),
                  onPressed: () => controller.zoomBy(1.1),
                ),
                IconButton(
                  icon: const Icon(Icons.undo),
                  onPressed: controller.canUndo ? controller.undo : null,
                ),
                IconButton(
                  icon: const Icon(Icons.redo),
                  onPressed: controller.canRedo ? controller.redo : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'مسح الكل',
                  onPressed: controller.clear,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(
        icon,
        color: selected ? AppColors.accent : AppColors.textMuted,
      ),
      style: IconButton.styleFrom(
        backgroundColor: selected ? AppColors.accentSoft : null,
      ),
    );
  }
}
