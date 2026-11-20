import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../../models/message.dart';
import '../../services/file_service.dart';
import 'avatar_widget.dart';
import 'file_type_helper.dart';
import 'reaction_bar.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String senderName;
  final String? senderAvatar;
  final String serverUrl;
  final String token;
  final VoidCallback? onReply;
  final VoidCallback? onOpenThread;
  final Function(String emoji)? onAddReaction;
  final Function(String label)? onToggleLabel;
  final VoidCallback? onToggleSaved;
  final VoidCallback? onDelete;
  final bool isHighlighted;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.senderName,
    this.senderAvatar,
    required this.serverUrl,
    required this.token,
    this.onReply,
    this.onOpenThread,
    this.onAddReaction,
    this.onToggleLabel,
    this.onToggleSaved,
    this.onDelete,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bubbleBg = isMe
        ? (isDark ? const Color(0xFF2563EB) : const Color(0xFF4A83BD))
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));

    final textColor = isMe ? Colors.white : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A));
    final timeStr = DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(message.ts));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        decoration: isHighlighted
            ? BoxDecoration(
                border: Border.all(color: Colors.amber, width: 2),
                borderRadius: BorderRadius.circular(16),
                color: Colors.amber.withOpacity(0.12),
              )
            : null,
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              AvatarWidget(
                userId: message.senderId,
                displayName: senderName,
                serverAvatarId: senderAvatar,
                serverUrl: serverUrl,
                size: 34,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(
                        senderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),

                  // Bubble container
                  GestureDetector(
                    onLongPress: () {
                      _showMessageActionsMenu(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: bubbleBg,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isMe ? 16 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 16),
                        ),
                        border: !isMe && isDark
                            ? Border.all(color: const Color(0xFF334155), width: 1)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Starred / Saved indicator
                          if (message.isSaved)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, size: 12, color: Colors.amber[300]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Saved',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber[300],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Labels badges row
                          if (message.labels.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: message.labels.map((lbl) => _buildLabelChip(lbl)).toList(),
                              ),
                            ),

                          // Body Markdown
                          if (message.body.isNotEmpty)
                            MarkdownBody(
                              data: message.body,
                              selectable: false,
                              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                                p: TextStyle(color: textColor, fontSize: 14),
                                code: TextStyle(
                                  backgroundColor: isMe ? Colors.blue[900] : (isDark ? Colors.black38 : Colors.grey[200]),
                                  color: textColor,
                                ),
                              ),
                            ),

                          // Attachments with specific file type icons
                          if (message.attachments.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...message.attachments.map((att) => _buildAttachmentTile(context, att, textColor)),
                          ],

                          // Timestamp
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isMe ? Colors.white70 : (isDark ? Colors.white54 : Colors.black45),
                                ),
                              ),
                              if (message.editedMs != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(edited)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMe ? Colors.white60 : Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Reactions row
                  if (message.reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        children: _groupReactions(message.reactions).entries.map((entry) {
                          return InkWell(
                            onTap: () => onAddReaction?.call(entry.key),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${entry.key} ${entry.value}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // Message Thread footer
                  if (message.replyCount > 0 || onOpenThread != null)
                    InkWell(
                      onTap: onOpenThread,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.forum_outlined, size: 14, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text(
                              message.replyCount > 0
                                  ? '${message.replyCount} ${message.replyCount == 1 ? "reply" : "replies"}'
                                  : 'Reply in thread',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelChip(String label) {
    Color bg = const Color(0xFF3B82F6).withOpacity(0.2);
    Color text = const Color(0xFF60A5FA);

    if (label.toLowerCase().contains('important')) {
      bg = const Color(0xFFEF4444).withOpacity(0.25);
      text = const Color(0xFFF87171);
    } else if (label.toLowerCase().contains('action') || label.toLowerCase().contains('todo')) {
      bg = const Color(0xFF10B981).withOpacity(0.25);
      text = const Color(0xFF34D399);
    } else if (label.toLowerCase().contains('bug')) {
      bg = const Color(0xFF8B5CF6).withOpacity(0.25);
      text = const Color(0xFFA78BFA);
    } else if (label.toLowerCase().contains('follow')) {
      bg = const Color(0xFFF59E0B).withOpacity(0.25);
      text = const Color(0xFFFBBF24);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: text.withOpacity(0.4), width: 0.8),
      ),
      child: Text(
        '#$label',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  Widget _buildAttachmentTile(BuildContext context, att, Color textColor) {
    final fileInfo = FileTypeHelper.getInfo(att.name);

    return InkWell(
      onTap: () async {
        try {
          await FileService.openAttachment(
            serverUrl: serverUrl,
            token: token,
            attachmentId: att.id,
            fileName: att.name,
          );
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open file: $e')),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Distinct file type badge & icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: fileInfo.badgeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(fileInfo.icon, size: 20, color: fileInfo.color),
                  Text(
                    fileInfo.label,
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      color: fileInfo.badgeTextColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    att.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 13),
                  ),
                  Text(
                    _formatBytes(att.size),
                    style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.75)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.open_in_new_rounded, size: 16, color: textColor.withOpacity(0.7)),
          ],
        ),
      ),
    );
  }

  Map<String, int> _groupReactions(List<Reaction> reactions) {
    final map = <String, int>{};
    for (final r in reactions) {
      map[r.emoji] = (map[r.emoji] ?? 0) + 1;
    }
    return map;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showMessageActionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Quick Reactions Row
              QuickReactionBar(
                onSelectEmoji: (emoji) {
                  Navigator.pop(ctx);
                  onAddReaction?.call(emoji);
                },
              ),
              const Divider(height: 16),

              // Reply in thread
              ListTile(
                leading: const Icon(Icons.forum_outlined, color: Color(0xFF38BDF8)),
                title: const Text('Reply in thread'),
                subtitle: const Text('Start or join a discussion thread'),
                onTap: () {
                  Navigator.pop(ctx);
                  onOpenThread?.call();
                },
              ),

              // Apply Label
              ListTile(
                leading: const Icon(Icons.label_outline_rounded, color: Color(0xFFF59E0B)),
                title: const Text('Apply Label'),
                subtitle: Text(message.labels.isEmpty ? 'Add tags like #Important, #Bug' : message.labels.join(', ')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showLabelPickerDialog(context);
                },
              ),

              // Save / Star
              ListTile(
                leading: Icon(
                  message.isSaved ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber,
                ),
                title: Text(message.isSaved ? 'Remove from Saved' : 'Save Message'),
                onTap: () {
                  Navigator.pop(ctx);
                  onToggleSaved?.call();
                },
              ),

              // Copy text
              if (message.body.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copy Text'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.body));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message copied to clipboard')),
                    );
                  },
                ),

              // Delete
              if (isMe && onDelete != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Delete Message', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete?.call();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showLabelPickerDialog(BuildContext context) {
    final availableLabels = ['Important', 'Action Item', 'Follow Up', 'Bug', 'Idea', 'Reference'];
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.label_rounded, color: Color(0xFFF59E0B)),
                  SizedBox(width: 8),
                  Text('Message Labels'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: availableLabels.map((lbl) {
                      final hasLabel = message.labels.contains(lbl);
                      return FilterChip(
                        label: Text(lbl),
                        selected: hasLabel,
                        onSelected: (_) {
                          onToggleLabel?.call(lbl);
                          setDialogState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Add Custom Label',
                      hintText: 'e.g. Design, Meeting',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          final text = controller.text.trim();
                          if (text.isNotEmpty) {
                            onToggleLabel?.call(text);
                            controller.clear();
                            setDialogState(() {});
                          }
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
