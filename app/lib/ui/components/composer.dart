import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'formatting_toolbar.dart';

class Composer extends StatefulWidget {
  final Function(String text, List<File> files) onSend;
  final VoidCallback? onTyping;

  const Composer({
    super.key,
    required this.onSend,
    this.onTyping,
  });

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<File> _selectedFiles = [];

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedFiles.isEmpty) return;

    widget.onSend(text, List.from(_selectedFiles));
    _textController.clear();
    setState(() {
      _selectedFiles.clear();
    });
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (final f in result.files) {
          if (f.path != null) {
            _selectedFiles.add(File(f.path!));
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Formatting toolbar docked cleanly above the composer
          FormattingToolbar(
            controller: _textController,
            focusNode: _focusNode,
          ),

          // Selected files preview chips
          if (_selectedFiles.isNotEmpty)
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedFiles.length,
                itemBuilder: (ctx, idx) {
                  final f = _selectedFiles[idx];
                  final name = f.path.split(Platform.pathSeparator).last;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6, top: 4),
                    child: Chip(
                      label: Text(name, style: const TextStyle(fontSize: 11)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () {
                        setState(() {
                          _selectedFiles.removeAt(idx);
                        });
                      },
                    ),
                  );
                },
              ),
            ),

          // Composer row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, size: 22),
                  tooltip: 'Attach universal file',
                  onPressed: _pickFiles,
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    maxLines: 5,
                    minLines: 1,
                    onChanged: (val) {
                      widget.onTyping?.call();
                    },
                    decoration: InputDecoration(
                      hintText: 'Write a message... (Markdown supported)',
                      hintStyle: TextStyle(
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.send_rounded,
                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                  ),
                  tooltip: 'Send message',
                  onPressed: _handleSend,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
