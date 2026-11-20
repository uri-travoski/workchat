import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/message.dart';
import '../../state/auth_state.dart';
import '../../state/chat_state.dart';
import '../components/composer.dart';
import '../components/message_bubble.dart';

class ThreadView extends StatelessWidget {
  final Message rootMessage;
  final VoidCallback onClose;

  const ThreadView({
    super.key,
    required this.rootMessage,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final chatState = context.watch<ChatState>();
    final authState = context.read<AuthState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final usersMap = {for (var u in chatState.users) u.id: u};
    final rootSender = usersMap[rootMessage.senderId];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.forum_outlined, size: 20, color: Color(0xFF38BDF8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thread',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Started by ${rootSender?.displayName ?? "User"} • ${rootMessage.replyCount} replies',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Root message preview
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFF2563EB),
                              child: Text(
                                (rootSender?.displayName.isNotEmpty ?? false) ? rootSender!.displayName[0] : 'U',
                                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              rootSender?.displayName ?? 'User',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(rootMessage.body, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Replies (${chatState.threadMessages.length})',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                ),

                // Thread replies
                ...chatState.threadMessages.map((m) {
                  final isMe = m.senderId == authState.currentUser?.id;
                  final sender = usersMap[m.senderId];
                  return MessageBubble(
                    message: m,
                    isMe: isMe,
                    senderName: sender?.displayName ?? 'User',
                    senderAvatar: sender?.avatarAttachment,
                    serverUrl: authState.serverUrl,
                    token: authState.token ?? '',
                    onAddReaction: (emoji) {
                      chatState.addReaction(m.id, emoji);
                    },
                    onToggleLabel: (label) {
                      chatState.toggleMessageLabel(m.convId, m.id, label);
                    },
                    onToggleSaved: () {
                      chatState.toggleMessageSaved(m.convId, m.id);
                    },
                    onDelete: () {
                      chatState.deleteMessage(m.convId, m.id);
                    },
                  );
                }),
              ],
            ),
          ),

          // Thread Composer
          Composer(
            onSend: (text, files) {
              chatState.sendThreadReply(text, files: files);
            },
          ),
        ],
      ),
    );
  }
}
