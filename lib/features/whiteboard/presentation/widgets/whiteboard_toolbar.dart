import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import 'whiteboard_controller.dart';

const _circuitSimulatorUrl = 'https://www.falstad.com/circuit/circuitjs.html';

/// Opens in a NEW tab/external app (not `_self` like the app's other outbound
/// links) so the student doesn't lose their in-progress canvas by navigating
/// the same tab away from it.
Future<void> _openCircuitSimulator() => launchUrl(
  Uri.parse(_circuitSimulatorUrl),
  mode: LaunchMode.externalApplication,
  webOnlyWindowName: '_blank',
);

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
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: Material(
            color: AppColors.surface,
            elevation: 4,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(22),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  _VerticalDivider(),
                  for (final c in _colors)
                    GestureDetector(
                      onTap: () => controller.setPenColor(c),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                controller.penColor.toARGB32() == c.toARGB32()
                                ? AppColors.accent
                                : AppColors.border,
                            width:
                                controller.penColor.toARGB32() == c.toARGB32()
                                ? 3
                                : 1,
                          ),
                        ),
                      ),
                    ),
                  _VerticalDivider(),
                  _CompactIconButton(
                    child: PopupMenuButton<PageStyle>(
                      tooltip: 'شكل الصفحة',
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.view_agenda_outlined,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      onSelected: controller.setPageStyle,
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: PageStyle.blank,
                          child: Text('صفحة فارغة'),
                        ),
                        PopupMenuItem(
                          value: PageStyle.ruled,
                          child: Text('صفحة مسطرة'),
                        ),
                      ],
                    ),
                  ),
                  _CompactIconButton(
                    icon: Icons.zoom_out,
                    onPressed: () => controller.zoomBy(0.9),
                  ),
                  _CompactIconButton(
                    icon: Icons.zoom_in,
                    onPressed: () => controller.zoomBy(1.1),
                  ),
                  _CompactIconButton(
                    icon: Icons.undo,
                    onPressed: controller.canUndo ? controller.undo : null,
                  ),
                  _CompactIconButton(
                    icon: Icons.redo,
                    onPressed: controller.canRedo ? controller.redo : null,
                  ),
                  _CompactIconButton(
                    icon: Icons.delete_outline,
                    tooltip: 'مسح الكل',
                    onPressed: controller.clear,
                  ),
                  _VerticalDivider(),
                  _CompactIconButton(
                    icon: Icons.memory,
                    tooltip: 'محاكي الدوائر الكهربية',
                    onPressed: _openCircuitSimulator,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: AppColors.border,
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
    return _CompactIconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onTap,
      color: selected ? AppColors.accent : AppColors.textMuted,
      background: selected ? AppColors.accentSoft : null,
    );
  }
}

/// A smaller-than-default [IconButton] (Material's own has a 48px minimum
/// tap target) — used throughout so the toolbar stays a slim strip and
/// leaves most of the screen to the canvas itself. Pass [child] instead of
/// [icon] to wrap a non-IconButton control (e.g. a [PopupMenuButton]) at
/// the same compact size.
class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.background,
    this.child,
  });

  final IconData? icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final Color? background;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final content =
        child ??
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
          icon: Icon(icon, size: 20, color: color),
          style: IconButton.styleFrom(backgroundColor: background),
        );
    return SizedBox(height: 32, child: Center(child: content));
  }
}
