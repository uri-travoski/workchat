import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/message.dart';
import '../../state/auth_state.dart';
import '../../state/chat_state.dart';
import '../../theme/theme_manager.dart';
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
    final themeMgr = context.watch<ThemeManager>();
    final activeTheme = themeMgr.activeTheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final usersMap = {for (var u in chatState.users) u.id: u};
    final rootSender = usersMap[rootMessage.senderId];

    return Container(
      decoration: BoxDecoration(
        color: activeTheme.chatStageBg(isDark),
        border: Border(
          left: BorderSide(
            color: activeTheme.borderColor(isDark),
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
              color: activeTheme.surfaceHeaderBg(isDark),
              border: Border(
                bottom: BorderSide(
                  color: activeTheme.borderColor(isDark),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.forum_outlined, size: 20, color: activeTheme.accentColor(isDark)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thread',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Started by ${rootSender?.displayName ?? "User"} • ${rootMessage.replyCount} replies',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
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
                      color: activeTheme.surfaceHeaderBg(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: activeTheme.borderColor(isDark),
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
                              backgroundColor: activeTheme.accentColor(isDark),
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
