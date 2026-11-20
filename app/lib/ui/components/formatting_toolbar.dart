import 'package:flutter/material.dart';

class FormattingToolbar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const FormattingToolbar({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  void _wrapSelection(String prefix, String suffix) {
    final text = controller.text;
    final selection = controller.selection;

    if (!selection.isValid || selection.isCollapsed) {
      final cursor = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
      final newText = text.substring(0, cursor) + prefix + suffix + text.substring(cursor);
      controller.text = newText;
      controller.selection = TextSelection.collapsed(offset: cursor + prefix.length);
    } else {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.substring(0, selection.start) + prefix + selectedText + suffix + text.substring(selection.end);
      controller.text = newText;
      controller.selection = TextSelection(
        baseOffset: selection.start + prefix.length,
        extentOffset: selection.end + prefix.length,
      );
    }
    focusNode.requestFocus();
  }

  void _insertLinePrefix(String linePrefix) {
    final text = controller.text;
    final selection = controller.selection;
    final cursor = selection.baseOffset >= 0 ? selection.baseOffset : text.length;

    // Insert prefix at line beginning
    int lineStart = text.lastIndexOf('\n', cursor - 1);
    lineStart = lineStart == -1 ? 0 : lineStart + 1;

    final newText = text.substring(0, lineStart) + linePrefix + text.substring(lineStart);
    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: cursor + linePrefix.length);
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _toolButton(
            icon: Icons.format_bold,
            tooltip: 'Bold (**text**)',
            onPressed: () => _wrapSelection('**', '**'),
            color: iconColor,
          ),
          _toolButton(
            icon: Icons.format_italic,
            tooltip: 'Italic (*text*)',
            onPressed: () => _wrapSelection('*', '*'),
            color: iconColor,
          ),
          _divider(isDark),
          _toolButton(
            icon: Icons.format_list_bulleted,
            tooltip: 'Bulleted List (- item)',
            onPressed: () => _insertLinePrefix('- '),
            color: iconColor,
          ),
          _toolButton(
            icon: Icons.format_list_numbered,
            tooltip: 'Numbered List (1. item)',
            onPressed: () => _insertLinePrefix('1. '),
            color: iconColor,
          ),
          _divider(isDark),
          _toolButton(
            icon: Icons.code,
            tooltip: 'Inline Code (`code`)',
            onPressed: () => _wrapSelection('`', '`'),
            color: iconColor,
          ),
          _toolButton(
            icon: Icons.integration_instructions,
            tooltip: 'Code Block (```block```)',
            onPressed: () => _wrapSelection('```\n', '\n```'),
            color: iconColor,
          ),
        ],
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      tooltip: tooltip,
      splashRadius: 18,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onPressed,
    );
  }

  Widget _divider(bool isDark) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
    );
  }
}
