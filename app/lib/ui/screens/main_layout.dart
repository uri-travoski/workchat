import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/conversation.dart';
import '../../state/auth_state.dart';
import '../../state/chat_state.dart';
import '../../state/hidden_chat_manager.dart';
import '../components/composer.dart';
import '../components/message_bubble.dart';
import 'hidden_lock_dialog.dart';
import 'settings_screen.dart';
import 'thread_view.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  String _selectedTab = 'All'; // "All", "DMs", "Channels", "Bots"
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showRightDrawer = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = context.watch<ChatState>();
    final authState = context.watch<AuthState>();
    final hiddenMgr = context.watch<HiddenChatManager>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isDesktop = MediaQuery.of(context).size.width >= 800;

    // Filter conversations based on tab, hidden state, and search query
    final filteredConvs = chatState.conversations.where((c) {
      // Hidden chat rule: exclude hidden chats unless unlocked
      final isHidden = hiddenMgr.isHidden(c.id);
      if (isHidden && !hiddenMgr.isUnlocked) {
        return false;
      }

      // Tab filter
      if (_selectedTab == 'DMs' && c.kind != 'dm') return false;
      if (_selectedTab == 'Channels' && c.kind != 'channel') return false;
      if (_selectedTab == 'Bots') {
        // Find if any member is a bot
        final isBotConv = chatState.users.any((u) => u.isBot && u.id == c.createdBy);
        if (!isBotConv) return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final name = c.name?.toLowerCase() ?? '';
        final topic = c.topic?.toLowerCase() ?? '';
        if (!name.contains(_searchQuery.toLowerCase()) && !topic.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList();

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Pane 1: Slim Left Icon Rail
            _buildLeftRail(context, isDark, hiddenMgr),

            // Pane 2: Middle Chat List Column
            SizedBox(
              width: 320,
              child: _buildChatListColumn(context, isDark, filteredConvs, chatState, hiddenMgr),
            ),

            // Pane 3: Main Chat Stage
            Expanded(
              child: _buildChatStage(context, isDark, chatState, authState),
            ),

            // Collapsible Right-hand Drawer (Threads, Media, Channel Info)
            if (chatState.activeThreadRoot != null || _showRightDrawer)
              SizedBox(
                width: 340,
                child: chatState.activeThreadRoot != null
                    ? ThreadView(
                        rootMessage: chatState.activeThreadRoot!,
                        onClose: () => chatState.closeThread(),
                      )
                    : _buildChannelInfoDrawer(context, isDark, chatState),
              ),
          ],
        ),
      );
    } else {
      // Mobile Layout
      return Scaffold(
        appBar: AppBar(
          title: Text(chatState.activeConversation?.name ?? 'WorkChat'),
          actions: [
            IconButton(
              icon: Icon(hiddenMgr.isUnlocked ? Icons.lock_open : Icons.lock_outline),
              tooltip: 'Hidden Chats PIN',
              onPressed: () {
                if (hiddenMgr.isUnlocked) {
                  hiddenMgr.lock();
                } else {
                  showDialog(context: context, builder: (_) => const HiddenLockDialog());
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
          ],
        ),
        drawer: Drawer(
          child: _buildChatListColumn(context, isDark, filteredConvs, chatState, hiddenMgr),
        ),
        body: _buildChatStage(context, isDark, chatState, authState),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: ['All', 'DMs', 'Channels', 'Bots'].indexOf(_selectedTab),
          onTap: (idx) {
            setState(() {
              _selectedTab = ['All', 'DMs', 'Channels', 'Bots'][idx];
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.forum_outlined), label: 'All'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'DMs'),
            BottomNavigationBarItem(icon: Icon(Icons.tag), label: 'Channels'),
            BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), label: 'Bots'),
          ],
        ),
      );
    }
  }

  Widget _buildLeftRail(BuildContext context, bool isDark, HiddenChatManager hiddenMgr) {
    final tabs = [
      {'name': 'All', 'icon': Icons.forum_outlined},
      {'name': 'DMs', 'icon': Icons.person_outline},
      {'name': 'Channels', 'icon': Icons.tag},
      {'name': 'Bots', 'icon': Icons.smart_toy_outlined},
    ];

    return Container(
      width: 68,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9), // Slate theme rail
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // App icon bubble
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
            ),
            alignment: Alignment.center,
            child: const Text('W', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
          ),
          const SizedBox(height: 24),

          // Folder Tabs
          Expanded(
            child: ListView(
              children: tabs.map((t) {
                final isSelected = _selectedTab == t['name'];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedTab = t['name'] as String;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            t['icon'] as IconData,
                            size: 20,
                            color: isSelected
                                ? const Color(0xFF38BDF8)
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t['name'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Lock Hidden Chats Button
          IconButton(
            icon: Icon(
              hiddenMgr.isUnlocked ? Icons.lock_open : Icons.lock_outline,
              color: hiddenMgr.isUnlocked ? const Color(0xFF38BDF8) : Colors.grey,
            ),
            tooltip: hiddenMgr.isUnlocked ? 'Lock Hidden Chats' : 'Unlock Hidden Chats (PIN)',
            onPressed: () {
              if (hiddenMgr.isUnlocked) {
                hiddenMgr.lock();
              } else {
                showDialog(context: context, builder: (_) => const HiddenLockDialog());
              }
            },
          ),

          // Settings Button
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildChatListColumn(BuildContext context, bool isDark, List<Conversation> convs, ChatState chatState, HiddenChatManager hiddenMgr) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Search & New Chat bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search chats...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_comment_outlined, size: 20),
                  tooltip: 'New Channel / DM',
                  onPressed: () => _showNewChatDialog(context),
                ),
              ],
            ),
          ),

          // Chat list
          Expanded(
            child: convs.isEmpty
                ? const Center(child: Text('No conversations found', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: convs.length,
                    itemBuilder: (ctx, idx) {
                      final c = convs[idx];
                      final isSelected = chatState.activeConversation?.id == c.id;
                      final isHidden = hiddenMgr.isHidden(c.id);

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        leading: CircleAvatar(
                          backgroundColor: c.kind == 'channel' ? const Color(0xFF4A83BD) : const Color(0xFF2563EB),
                          child: Icon(c.kind == 'channel' ? Icons.tag : Icons.person, color: Colors.white, size: 18),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.name ?? (c.kind == 'self' ? 'Notes to Self' : 'Direct Message'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                            if (isHidden)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.visibility_off, size: 14, color: Colors.amber),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          c.topic ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                        trailing: c.unreadCount > 0
                            ? Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                                child: Text('${c.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              )
                            : null,
                        onTap: () {
                          chatState.selectConversation(c);
                        },
                        onLongPress: () {
                          _showChatOptionsModal(context, c, hiddenMgr);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatStage(BuildContext context, bool isDark, ChatState chatState, AuthState authState) {
    final activeConv = chatState.activeConversation;
    if (activeConv == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 48, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            const Text('Select a chat to begin messaging', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final messages = chatState.getMessages(activeConv.id);
    final usersMap = {for (var u in chatState.users) u.id: u};
    final typingUser = chatState.getTyping(activeConv.id);

    return Column(
      children: [
        // Stage Header
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeConv.name ?? 'Conversation',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (typingUser != null)
                      Text(
                        '$typingUser is typing...',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8), fontStyle: FontStyle.italic),
                      )
                    else if (activeConv.topic != null && activeConv.topic!.isNotEmpty)
                      Text(
                        activeConv.topic!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                tooltip: 'Channel / Chat Info',
                onPressed: () {
                  setState(() => _showRightDrawer = !_showRightDrawer);
                },
              ),
            ],
          ),
        ),

        // Messages timeline
        Expanded(
          child: messages.isEmpty
              ? const Center(child: Text('No messages yet. Send a message to start!', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (ctx, idx) {
                    final m = messages[idx];
                    final isMe = m.senderId == authState.currentUser?.id;
                    final sender = usersMap[m.senderId];
                    return MessageBubble(
                      message: m,
                      isMe: isMe,
                      senderName: sender?.displayName ?? 'User',
                      senderAvatar: sender?.avatarAttachment,
                      serverUrl: authState.serverUrl,
                      token: authState.token ?? '',
                      onOpenThread: () {
                        chatState.openThread(m);
                      },
                      onAddReaction: (emoji) {
                        chatState.addReaction(m.id, emoji);
                      },
                    );
                  },
                ),
        ),

        // Composer with Slack-style Markdown formatting toolbar
        Composer(
          onSend: (text, files) {
            chatState.sendMessage(text, files: files);
          },
          onTyping: () {
            chatState.sendTyping();
          },
        ),
      ],
    );
  }

  Widget _buildChannelInfoDrawer(BuildContext context, bool isDark, ChatState chatState) {
    final c = chatState.activeConversation;
    if (c == null) return const SizedBox();

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
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text('Chat Info', style: TextStyle(fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => _showRightDrawer = false)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name ?? 'Chat', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(c.topic ?? 'No topic set', style: const TextStyle(color: Colors.grey)),
                const Divider(height: 32),
                const Text('Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.push_pin_outlined),
                  title: const Text('Pinned Messages'),
                  dense: true,
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.folder_shared_outlined),
                  title: const Text('Shared Files & Media'),
                  dense: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNewChatDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final topicCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('New Channel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Channel Name', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: topicCtrl, decoration: const InputDecoration(labelText: 'Topic / Description', border: OutlineInputBorder())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  final chatState = context.read<ChatState>();
                  final newConv = await chatState.api.createChannel(name, topicCtrl.text.trim(), []);
                  chatState.conversations.insert(0, newConv);
                  chatState.selectConversation(newConv);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showChatOptionsModal(BuildContext context, Conversation c, HiddenChatManager hiddenMgr) {
    final isHidden = hiddenMgr.isHidden(c.id);
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(isHidden ? Icons.visibility : Icons.visibility_off, color: Colors.amber),
                title: Text(isHidden ? 'Unhide Chat' : 'Hide Chat with PIN'),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (!hiddenMgr.hasPin) {
                    await showDialog(context: context, builder: (_) => const HiddenLockDialog());
                  }
                  if (hiddenMgr.hasPin) {
                    await hiddenMgr.toggleHidden(c.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isHidden ? 'Chat unhidden' : 'Chat marked as Hidden')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
