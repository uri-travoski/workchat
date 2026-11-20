import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../../models/message.dart';
import '../../services/file_service.dart';
import 'avatar_widget.dart';
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
                    _showReactionsPopup(context);
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
                        // Body Markdown
                        if (message.body.isNotEmpty)
                          MarkdownBody(
                            data: message.body,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                              p: TextStyle(color: textColor, fontSize: 14),
                              code: TextStyle(
                                backgroundColor: isMe ? Colors.blue[900] : (isDark ? Colors.black38 : Colors.grey[200]),
                                color: textColor,
                              ),
                            ),
                          ),

                        // Attachments
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
                        return Container(
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
    );
  }

  Widget _buildAttachmentTile(BuildContext context, att, Color textColor) {
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file, size: 24, color: Colors.white70),
            const SizedBox(width: 8),
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
                    style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.open_in_new, size: 16, color: Colors.white70),
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

  void _showReactionsPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return Center(
          child: QuickReactionBar(
            onSelectEmoji: (emoji) {
              Navigator.pop(ctx);
              onAddReaction?.call(emoji);
            },
          ),
        );
      },
    );
  }
}
