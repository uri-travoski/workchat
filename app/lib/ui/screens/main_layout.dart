import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../state/auth_state.dart';
import '../../state/chat_state.dart';
import '../../state/hidden_chat_manager.dart';
import '../../theme/theme_manager.dart';
import '../components/composer.dart';
import '../components/message_bubble.dart';
import 'hidden_lock_dialog.dart';
import 'mobile_chat_screen.dart';
import 'settings_screen.dart';
import 'thread_view.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  // Navigation tabs: All, DMs, Channels, Bots, Settings
  int _navIndex = 0;
  static const List<String> _tabs = ['All', 'DMs', 'Channels', 'Bots', 'Settings'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Platform.isAndroid || Platform.isIOS) {
        if (mounted) {
          context.read<ChatState>().selectConversation(null);
        }
      }
    });
  }

  // Search in chat list
  bool _isSearchingList = false;
  final TextEditingController _listSearchController = TextEditingController();
  String _listSearchQuery = '';

  // WhatsApp-style Search inside conversation
  bool _isSearchingConv = false;
  final TextEditingController _convSearchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<int> _matchedIndices = [];
  int _currentMatchPointer = 0;

  // Filters & Sorting in conversation list
  bool _filterOnlyUnread = false;
  bool _hideMuted = false;
  String _sortMode = 'recent'; // 'recent' or 'alpha'
  bool _viewingAllThreads = false;

  // Filter inside conversation
  String? _selectedMessageLabel;
  bool _filterOnlySaved = false;

  bool _showRightDrawer = false;

  @override
  void dispose() {
    _listSearchController.dispose();
    _convSearchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onConvSearchChanged(String query, List<Message> messages) {
    if (query.trim().isEmpty) {
      setState(() {
        _matchedIndices = [];
        _currentMatchPointer = 0;
      });
      return;
    }

    final lower = query.toLowerCase();
    final matches = <int>[];
    for (int i = 0; i < messages.length; i++) {
      if (messages[i].body.toLowerCase().contains(lower)) {
        matches.add(i);
      }
    }

    setState(() {
      _matchedIndices = matches;
      _currentMatchPointer = matches.isNotEmpty ? 0 : 0;
    });

    if (matches.isNotEmpty) {
      _scrollToMatch(matches[0]);
    }
  }

  void _jumpToNextMatch() {
    if (_matchedIndices.isEmpty) return;
    setState(() {
      _currentMatchPointer = (_currentMatchPointer + 1) % _matchedIndices.length;
    });
    _scrollToMatch(_matchedIndices[_currentMatchPointer]);
  }

  void _jumpToPrevMatch() {
    if (_matchedIndices.isEmpty) return;
    setState(() {
      _currentMatchPointer = (_currentMatchPointer - 1 + _matchedIndices.length) % _matchedIndices.length;
    });
    _scrollToMatch(_matchedIndices[_currentMatchPointer]);
  }

  void _scrollToMatch(int index) {
    // Reverse ListView: approximate height ~72px per bubble
    if (_scrollController.hasClients) {
      final target = (index * 76.0).clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = context.watch<ChatState>();
    final authState = context.watch<AuthState>();
    final hiddenMgr = context.watch<HiddenChatManager>();
    final themeMgr = context.watch<ThemeManager>();
    final activeTheme = themeMgr.activeTheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobileDevice = Platform.isAndroid || Platform.isIOS;
    final isDesktop = !isMobileDevice && MediaQuery.of(context).size.width >= 900;

    // Filter and sort conversations
    final selectedCategory = _tabs[_navIndex];

    List<Conversation> filteredConvs = chatState.conversations.where((c) {
      // Hidden chat rule
      final isHidden = hiddenMgr.isHidden(c.id);
      if (isHidden && !hiddenMgr.isUnlocked) return false;

      // Unread filter
      if (_filterOnlyUnread && c.unreadCount == 0) return false;

      // Muted filter
      if (_hideMuted && c.isMuted) return false;

      // Tab category
      if (selectedCategory == 'DMs' && c.kind != 'dm') return false;
      if (selectedCategory == 'Channels' && c.kind != 'channel') return false;
      if (selectedCategory == 'Bots') {
        final isBot = chatState.users.any((u) => u.isBot && u.id == c.createdBy);
        if (!isBot) return false;
      }

      // Search query in list
      if (_listSearchQuery.isNotEmpty) {
        final q = _listSearchQuery.toLowerCase();
        final name = (c.name ?? '').toLowerCase();
        final topic = (c.topic ?? '').toLowerCase();
        if (!name.contains(q) && !topic.contains(q)) return false;
      }

      return true;
    }).toList();

    // Separate pinned and unpinned
    final pinnedConvs = filteredConvs.where((c) => c.isPinned).toList()
      ..sort((a, b) => a.pinOrder.compareTo(b.pinOrder));

    final unpinnedConvs = filteredConvs.where((c) => !c.isPinned).toList();

    // Apply sorting to unpinned conversations
    if (_sortMode == 'alpha') {
      unpinnedConvs.sort((a, b) => (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()));
    } else {
      unpinnedConvs.sort((a, b) => (b.lastTs ?? b.createdMs).compareTo(a.lastTs ?? a.createdMs));
    }

    if (isDesktop) {
      if (chatState.activeConversation == null && chatState.conversations.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && chatState.activeConversation == null) {
            chatState.selectConversation(chatState.conversations.first);
          }
        });
      }

      // 3-Pane Desktop Layout
      return Scaffold(
        body: Row(
          children: [
            // Pane 1: Slim Left Icon Rail
            _buildLeftRail(context, isDark, hiddenMgr),

            // Pane 2: Middle Chat List Column
            SizedBox(
              width: 320,
              child: _navIndex == 4
                  ? const SettingsScreen(showBackButton: false)
                  : _buildChatListColumn(context, isDark, pinnedConvs, unpinnedConvs, chatState, hiddenMgr, isDesktop: true),
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
    }

    // Mobile Layout: Clean view switching with high contrast bottom navigation
    if (_navIndex == 4) {
      // Settings Screen in bottom nav
      return Scaffold(
        body: const SettingsScreen(showBackButton: false),
        bottomNavigationBar: _buildBottomNav(context),
      );
    }

    // Default Mobile View: Always show the Conversations List screen with Bottom Navigation
    return Scaffold(
      backgroundColor: activeTheme.chatListBg(isDark),
      appBar: _buildMobileListAppBar(context, hiddenMgr),
      body: _viewingAllThreads
          ? _buildAllThreadsView(context, isDark, chatState, isDesktop: false)
          : _buildChatListColumn(context, isDark, pinnedConvs, unpinnedConvs, chatState, hiddenMgr, isDesktop: false),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  PreferredSizeWidget _buildMobileListAppBar(BuildContext context, HiddenChatManager hiddenMgr) {
    final themeMgr = context.watch<ThemeManager>();
    final activeTheme = themeMgr.activeTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isSearchingList) {
      return AppBar(
        backgroundColor: activeTheme.surfaceHeaderBg(isDark),
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isSearchingList = false;
              _listSearchQuery = '';
              _listSearchController.clear();
            });
          },
        ),
        title: TextField(
          controller: _listSearchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search chats, topics...',
            border: InputBorder.none,
          ),
          onChanged: (val) {
            setState(() => _listSearchQuery = val);
          },
        ),
        actions: [
          if (_listSearchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _listSearchQuery = '';
                  _listSearchController.clear();
                });
              },
            ),
        ],
      );
    }

    return AppBar(
      backgroundColor: activeTheme.surfaceHeaderBg(isDark),
      elevation: 1,
      title: Text(_viewingAllThreads ? 'All Message Threads' : 'WorkChat'),
      actions: [
        // Search icon to the left of menu
        IconButton(
          icon: const Icon(Icons.search_rounded),
          tooltip: 'Search conversations',
          onPressed: () {
            setState(() => _isSearchingList = true);
          },
        ),

        // Menu icon (⋮) in top right corner
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          tooltip: 'Options',
          onSelected: (value) {
            if (value == 'hidden_toggle') {
              if (hiddenMgr.isUnlocked) {
                hiddenMgr.lock();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hidden chats locked')),
                );
              } else {
                showDialog(context: context, builder: (_) => const HiddenLockDialog());
              }
            } else if (value == 'threads') {
              setState(() => _viewingAllThreads = !_viewingAllThreads);
            } else if (value == 'unread_filter') {
              setState(() => _filterOnlyUnread = !_filterOnlyUnread);
            } else if (value == 'hide_muted') {
              setState(() => _hideMuted = !_hideMuted);
            } else if (value == 'sort_recent') {
              setState(() => _sortMode = 'recent');
            } else if (value == 'sort_alpha') {
              setState(() => _sortMode = 'alpha');
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'hidden_toggle',
              child: Row(
                children: [
                  Icon(hiddenMgr.isUnlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(hiddenMgr.isUnlocked ? 'Lock Hidden Chats' : 'Unlock Hidden Chats'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'threads',
              child: Row(
                children: [
                  Icon(_viewingAllThreads ? Icons.chat_bubble_outline : Icons.forum_outlined, size: 20, color: const Color(0xFF38BDF8)),
                  const SizedBox(width: 10),
                  Text(_viewingAllThreads ? 'Back to All Chats' : 'View All Threads'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'unread_filter',
              child: Row(
                children: [
                  Icon(_filterOnlyUnread ? Icons.mark_email_read_rounded : Icons.mark_email_unread_outlined, size: 20),
                  const SizedBox(width: 10),
                  Text(_filterOnlyUnread ? 'Show All Chats' : 'Filter by Unread'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'hide_muted',
              child: Row(
                children: [
                  Icon(_hideMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined, size: 20),
                  const SizedBox(width: 10),
                  Text(_hideMuted ? 'Show Muted Chats' : 'Hide Muted Chats'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'sort_recent',
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text('Sort by Recent ${_sortMode == "recent" ? "✓" : ""}'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'sort_alpha',
              child: Row(
                children: [
                  const Icon(Icons.sort_by_alpha_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text('Sort by A-Z ${_sortMode == "alpha" ? "✓" : ""}'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final theme = Theme.of(context);
    final themeMgr = context.watch<ThemeManager>();
    final activeTheme = themeMgr.activeTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: activeTheme.surfaceHeaderBg(isDark),
        border: Border(
          top: BorderSide(color: activeTheme.borderColor(isDark), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _navIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: activeTheme.surfaceHeaderBg(isDark),
        selectedItemColor: activeTheme.accentColor(isDark),
        unselectedItemColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        onTap: (idx) {
          setState(() {
            _navIndex = idx;
            _viewingAllThreads = false;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.forum_outlined), activeIcon: Icon(Icons.forum_rounded), label: 'All'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person_rounded), label: 'DMs'),
          BottomNavigationBarItem(icon: Icon(Icons.tag), activeIcon: Icon(Icons.tag_rounded), label: 'Channels'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), activeIcon: Icon(Icons.smart_toy_rounded), label: 'Bots'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildLeftRail(BuildContext context, bool isDark, HiddenChatManager hiddenMgr) {
    final themeMgr = context.watch<ThemeManager>();
    final activeTheme = themeMgr.activeTheme;

    final tabs = [
      {'name': 'All', 'icon': Icons.forum_outlined},
      {'name': 'DMs', 'icon': Icons.person_outline},
      {'name': 'Channels', 'icon': Icons.tag},
      {'name': 'Bots', 'icon': Icons.smart_toy_outlined},
      {'name': 'Settings', 'icon': Icons.settings_outlined},
    ];

    return Container(
      width: 68,
      decoration: BoxDecoration(
        color: activeTheme.leftRailBg(isDark),
        border: Border(right: BorderSide(color: activeTheme.borderColor(isDark), width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // App icon bubble
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: activeTheme.surfaceHeaderBg(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: activeTheme.accentColor(isDark), width: 1.5),
            ),
            alignment: Alignment.center,
            child: const Text('W', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
          ),
          const SizedBox(height: 24),

          // Folder Tabs + Settings
          Expanded(
            child: ListView.builder(
              itemCount: tabs.length,
              itemBuilder: (ctx, idx) {
                final isSelected = _navIndex == idx;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _navIndex = idx;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected ? activeTheme.accentColor(isDark) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(tabs[idx]['icon'] as IconData, color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54), size: 20),
                          const SizedBox(height: 2),
                          Text(
                            tabs[idx]['name'] as String,
                            style: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatListColumn(
    BuildContext context,
    bool isDark,
    List<Conversation> pinnedConvs,
    List<Conversation> unpinnedConvs,
    ChatState chatState,
    HiddenChatManager hiddenMgr, {
    required bool isDesktop,
  }) {
    final themeMgr = context.watch<ThemeManager>();
    final activeTheme = themeMgr.activeTheme;

    return Container(
      decoration: BoxDecoration(
        color: activeTheme.chatListBg(isDark),
        border: Border(right: BorderSide(color: activeTheme.borderColor(isDark), width: isDesktop ? 1 : 0)),
      ),
      child: Column(
        children: [
          // Pinned + Unpinned List
          Expanded(
            child: (pinnedConvs.isEmpty && unpinnedConvs.isEmpty)
                ? const Center(child: Text('No conversations found', style: TextStyle(color: Colors.grey)))
                : CustomScrollView(
                    slivers: [
                      // Section 1: Pinned Conversations (Drag-and-Drop Reorderable)
                      if (pinnedConvs.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.push_pin_rounded, size: 14, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 6),
                                Text(
                                  'PINNED (${pinnedConvs.length}) — Drag to reorder',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B), letterSpacing: 0.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverReorderableList(
                          itemCount: pinnedConvs.length,
                          onReorder: (oldIdx, newIdx) {
                            chatState.reorderPinnedConversations(oldIdx, newIdx);
                          },
                          itemBuilder: (ctx, idx) {
                            final c = pinnedConvs[idx];
                            return ReorderableDelayedDragStartListener(
                              key: ValueKey(c.id),
                              index: idx,
                              child: _buildConversationTile(context, c, isDark, chatState, hiddenMgr, isPinned: true, isDesktop: isDesktop),
                            );
                          },
                        ),
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Divider(),
                          ),
                        ),
                      ],

                      // Section 2: Regular / Unpinned Conversations
                      if (unpinnedConvs.isNotEmpty) ...[
                        if (pinnedConvs.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 4),
                              child: Text(
                                'ALL CONVERSATIONS (${_sortMode == "alpha" ? "A-Z" : "Recent"})',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black54),
                              ),
                            ),
                          ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, idx) {
                              final c = unpinnedConvs[idx];
                              return _buildConversationTile(context, c, isDark, chatState, hiddenMgr, isPinned: false, isDesktop: isDesktop);
                            },
                            childCount: unpinnedConvs.length,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(
    BuildContext context,
    Conversation c,
    bool isDark,
    ChatState chatState,
    HiddenChatManager hiddenMgr, {
    required bool isPinned,
    required bool isDesktop,
  }) {
    final themeMgr = context.watch<ThemeManager>();
    final activeTheme = themeMgr.activeTheme;
    final isSelected = chatState.activeConversation?.id == c.id;
    final isHidden = hiddenMgr.isHidden(c.id);

    return ListTile(
      selected: isDesktop && isSelected,
      selectedTileColor: activeTheme.surfaceHeaderBg(isDark),
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: activeTheme.accentColor(isDark),
            child: Icon(c.kind == 'channel' ? Icons.tag : Icons.person, color: Colors.white, size: 18),
          ),
          if (isPinned)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
                child: const Icon(Icons.push_pin, size: 10, color: Colors.white),
              ),
            ),
        ],
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
          if (c.isMuted)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.notifications_off_outlined, size: 14, color: Colors.grey),
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: activeTheme.accentColor(isDark), borderRadius: const BorderRadius.all(Radius.circular(10))),
              child: Text('${c.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          if (isPinned)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.drag_indicator_rounded, size: 18, color: Colors.grey),
            ),
        ],
      ),
      onTap: () {
        chatState.selectConversation(c);
        if (!isDesktop) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MobileChatScreen(conversation: c),
            ),
          ).then((_) {
            chatState.selectConversation(null);
          });
        }
      },
      onLongPress: () {
        _showChatOptionsModal(context, c, hiddenMgr, chatState);
      },
    );
  }

  Widget _buildAllThreadsView(BuildContext context, bool isDark, ChatState chatState, {required bool isDesktop}) {
    final themeMgr = context.watch<ThemeManager>();
    final activeTheme = themeMgr.activeTheme;
    final threadRoots = chatState.getAllThreadRootMessages();
    final usersMap = {for (var u in chatState.users) u.id: u};

    if (threadRoots.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No message threads found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: threadRoots.length,
      itemBuilder: (ctx, idx) {
        final m = threadRoots[idx];
        final sender = usersMap[m.senderId];
        final conv = chatState.conversations.firstWhere(
          (c) => c.id == m.convId,
          orElse: () => Conversation(id: m.convId, kind: 'channel', name: 'Chat', createdMs: 0),
        );

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: activeTheme.accentColor(isDark),
              child: const Icon(Icons.forum_rounded, color: Colors.white, size: 18),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    sender?.displayName ?? 'User',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Text(
                  'in #${conv.name ?? "chat"}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(m.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.reply_rounded, size: 14, color: activeTheme.accentColor(isDark)),
                    const SizedBox(width: 4),
                    Text(
                      '${m.replyCount} replies',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: activeTheme.accentColor(isDark)),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () {
              chatState.selectConversation(conv);
              chatState.openThread(m);
              setState(() => _viewingAllThreads = false);
              if (!isDesktop) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MobileChatScreen(conversation: conv),
                  ),
                ).then((_) {
                  chatState.selectConversation(null);
                  chatState.closeThread();
                });
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildChatStage(
    BuildContext context,
    bool isDark,
    ChatState chatState,
    AuthState authState, {
    bool isMobile = false,
  }) {
    final themeMgr = context.watch<ThemeManager>();
    final activeTheme = themeMgr.activeTheme;
    final activeConv = chatState.activeConversation;
    if (activeConv == null) {
      return Container(
        color: activeTheme.chatStageBg(isDark),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined, size: 48, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              const SizedBox(height: 12),
              const Text('Select a chat to begin messaging', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    var messages = chatState.getMessages(activeConv.id);
    final usersMap = {for (var u in chatState.users) u.id: u};
    final typingUser = chatState.getTyping(activeConv.id);

    // Apply inside-conversation filters: label & saved
    if (_selectedMessageLabel != null) {
      messages = messages.where((m) => m.labels.contains(_selectedMessageLabel)).toList();
    }
    if (_filterOnlySaved) {
      messages = messages.where((m) => m.isSaved).toList();
    }

    return Container(
      color: activeTheme.chatStageBg(isDark),
      child: Column(
        children: [
        // Stage Header (or WhatsApp-style search header)
        if (_isSearchingConv)
          _buildConvSearchHeader(context, messages)
        else
          _buildConvNormalHeader(context, activeConv, isDark, typingUser, chatState, isMobile),

        // Filter active banner (if filtered by label or saved)
        if (_selectedMessageLabel != null || _filterOnlySaved)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: const Color(0xFFF59E0B).withOpacity(0.15),
            child: Row(
              children: [
                const Icon(Icons.filter_alt_rounded, size: 16, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedMessageLabel != null
                        ? 'Filtered by #$_selectedMessageLabel (${messages.length} messages)'
                        : 'Filtered by Saved Messages (${messages.length} messages)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedMessageLabel = null;
                      _filterOnlySaved = false;
                    });
                  },
                  child: const Text('Clear Filter', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),

        // Messages timeline
        Expanded(
          child: messages.isEmpty
              ? const Center(child: Text('No messages found', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (ctx, idx) {
                    final m = messages[idx];
                    final isMe = m.senderId == authState.currentUser?.id;
                    final sender = usersMap[m.senderId];
                    final isHighlighted = _matchedIndices.contains(idx) &&
                        _matchedIndices.indexOf(idx) == _currentMatchPointer;

                    return MessageBubble(
                      message: m,
                      isMe: isMe,
                      senderName: sender?.displayName ?? 'User',
                      senderAvatar: sender?.avatarAttachment,
                      serverUrl: authState.serverUrl,
                      token: authState.token ?? '',
                      isHighlighted: isHighlighted,
                      onOpenThread: () {
                        _handleOpenThread(context, m, chatState, isMobile);
                      },
                      onAddReaction: (emoji) {
                        chatState.addReaction(m.id, emoji);
                      },
                      onToggleLabel: (label) {
                        chatState.toggleMessageLabel(activeConv.id, m.id, label);
                      },
                      onToggleSaved: () {
                        chatState.toggleMessageSaved(activeConv.id, m.id);
                      },
                      onDelete: () {
                        chatState.deleteMessage(activeConv.id, m.id);
                      },
                    );
                  },
                ),
        ),

        // Composer
        Composer(
          onSend: (text, files) {
            chatState.sendMessage(text, files: files);
          },
          onTyping: () {
            chatState.sendTyping();
          },
        ),
      ],
      ),
    );
  }

  Widget _buildConvNormalHeader(
    BuildContext context,
    Conversation activeConv,
    bool isDark,
    String? typingUser,
    ChatState chatState,
    bool isMobile,
  ) {
    final hiddenMgr = context.watch<HiddenChatManager>();
    final themeMgr = context.watch<ThemeManager>();
    final activeTheme = themeMgr.activeTheme;
    final isHidden = hiddenMgr.isHidden(activeConv.id);

    return SafeArea(
      top: isMobile,
      bottom: false,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: activeTheme.surfaceHeaderBg(isDark),
          border: Border(bottom: BorderSide(color: activeTheme.borderColor(isDark), width: 1)),
        ),
        child: Row(
          children: [
            // Mobile Back button
            if (isMobile)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to conversations',
                onPressed: () {
                  chatState.selectConversation(null);
                },
              ),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        activeConv.name ?? 'Conversation',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    if (isHidden)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.lock_rounded, size: 14, color: Colors.amber),
                      ),
                  ],
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
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),

          // Search icon to the left of menu
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search in conversation',
            onPressed: () {
              setState(() {
                _isSearchingConv = true;
                _matchedIndices = [];
                _currentMatchPointer = 0;
              });
            },
          ),

          // Menu icon (⋮) in top right corner
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Chat Options',
            onSelected: (value) {
              if (value == 'lock_chat') {
                if (!hiddenMgr.hasPin) {
                  showDialog(context: context, builder: (_) => const HiddenLockDialog());
                } else {
                  hiddenMgr.toggleHidden(activeConv.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(hiddenMgr.isHidden(activeConv.id) ? 'Chat marked as Hidden' : 'Chat unhidden')),
                  );
                }
              } else if (value == 'filter_label') {
                _showFilterByLabelDialog(context, activeConv, chatState);
              } else if (value == 'filter_saved') {
                setState(() => _filterOnlySaved = !_filterOnlySaved);
              } else if (value == 'view_threads') {
                _showConversationThreadsDrawer(context, activeConv, chatState, isMobile);
              } else if (value == 'chat_info') {
                setState(() => _showRightDrawer = !_showRightDrawer);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'lock_chat',
                child: Row(
                  children: [
                    Icon(isHidden ? Icons.lock_open_rounded : Icons.lock_outline_rounded, size: 20),
                    const SizedBox(width: 10),
                    Text(isHidden ? 'Unlock / Unhide Chat' : 'Lock / Hide Chat with PIN'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'filter_label',
                child: Row(
                  children: [
                    Icon(Icons.label_outline_rounded, size: 20, color: Color(0xFFF59E0B)),
                    SizedBox(width: 10),
                    Text('Filter by Label'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'filter_saved',
                child: Row(
                  children: [
                    Icon(_filterOnlySaved ? Icons.star_rounded : Icons.star_outline_rounded, size: 20, color: Colors.amber),
                    const SizedBox(width: 10),
                    Text(_filterOnlySaved ? 'Show All Messages' : 'Filter by Saved Messages'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'view_threads',
                child: Row(
                  children: [
                    Icon(Icons.forum_outlined, size: 20, color: Color(0xFF38BDF8)),
                    SizedBox(width: 10),
                    Text('View Discussion Threads'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'chat_info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Chat Info & Details'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  // WhatsApp-style Search Bar inside Conversation
  Widget _buildConvSearchHeader(BuildContext context, List<Message> messages) {
    final themeMgr = context.watch<ThemeManager>();
    final activeTheme = themeMgr.activeTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final matchCount = _matchedIndices.length;
    final currentPos = matchCount > 0 ? _currentMatchPointer + 1 : 0;

    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: activeTheme.surfaceHeaderBg(isDark),
          border: Border(bottom: BorderSide(color: activeTheme.borderColor(isDark), width: 1)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _isSearchingConv = false;
                  _convSearchController.clear();
                  _matchedIndices = [];
                  _currentMatchPointer = 0;
                });
              },
            ),
          Expanded(
            child: TextField(
              controller: _convSearchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search in conversation...',
                border: InputBorder.none,
              ),
              onChanged: (query) => _onConvSearchChanged(query, messages),
            ),
          ),
          Text(
            matchCount > 0 ? '$currentPos of $matchCount' : '0 found',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            tooltip: 'Previous occurrence',
            onPressed: matchCount > 0 ? _jumpToPrevMatch : null,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            tooltip: 'Next occurrence',
            onPressed: matchCount > 0 ? _jumpToNextMatch : null,
          ),
        ],
      ),
    ),
  );
}

  void _handleOpenThread(BuildContext context, Message m, ChatState chatState, bool isMobile) {
    chatState.openThread(m);
    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.85,
            child: ThreadView(
              rootMessage: m,
              onClose: () {
                Navigator.pop(ctx);
                chatState.closeThread();
              },
            ),
          );
        },
      );
    }
  }

  void _showFilterByLabelDialog(BuildContext context, Conversation activeConv, ChatState chatState) {
    final messages = chatState.getMessages(activeConv.id);
    final allLabels = <String>{};
    for (final m in messages) {
      allLabels.addAll(m.labels);
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.label_rounded, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Text('Filter Messages by Label'),
            ],
          ),
          content: allLabels.isEmpty
              ? const Text('No labels have been applied to messages in this chat yet. Long press any message to add a label!')
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Show All (Clear Filter)'),
                      onPressed: () {
                        setState(() => _selectedMessageLabel = null);
                        Navigator.pop(ctx);
                      },
                    ),
                    ...allLabels.map((lbl) {
                      return ChoiceChip(
                        label: Text('#$lbl'),
                        selected: _selectedMessageLabel == lbl,
                        onSelected: (selected) {
                          setState(() => _selectedMessageLabel = selected ? lbl : null);
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showConversationThreadsDrawer(BuildContext context, Conversation activeConv, ChatState chatState, bool isMobile) {
    final messages = chatState.getMessages(activeConv.id);
    final threads = messages.where((m) => m.replyCount > 0 && m.threadRoot == null).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.forum_rounded, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 8),
                    Text(
                      'Threads in #${activeConv.name ?? "chat"}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: threads.isEmpty
                      ? const Center(child: Text('No threads found in this chat.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: threads.length,
                          itemBuilder: (subCtx, idx) {
                            final tm = threads[idx];
                            return Card(
                              child: ListTile(
                                title: Text(tm.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                                subtitle: Text('${tm.replyCount} replies'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _handleOpenThread(context, tm, chatState, isMobile);
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChatOptionsModal(BuildContext context, Conversation c, HiddenChatManager hiddenMgr, ChatState chatState) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(c.isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: Colors.amber),
                title: Text(c.isPinned ? 'Unpin Conversation' : 'Pin to Top'),
                onTap: () {
                  chatState.togglePinConversation(c.id);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(c.isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
                title: Text(c.isMuted ? 'Unmute Notifications' : 'Mute Notifications'),
                onTap: () {
                  chatState.toggleMuteConversation(c.id);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined, color: Colors.blueAccent),
                title: Text(hiddenMgr.isHidden(c.id) ? 'Unhide Chat' : 'Hide Chat (PIN-Protected)'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (!hiddenMgr.hasPin) {
                    showDialog(context: context, builder: (_) => const HiddenLockDialog());
                  } else {
                    hiddenMgr.toggleHidden(c.id);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChannelInfoDrawer(BuildContext context, bool isDark, ChatState chatState) {
    final themeMgr = context.watch<ThemeManager>();
    final activeTheme = themeMgr.activeTheme;
    final c = chatState.activeConversation;
    if (c == null) return const SizedBox();

    return Container(
      decoration: BoxDecoration(
        color: activeTheme.chatStageBg(isDark),
        border: Border(left: BorderSide(color: activeTheme.borderColor(isDark))),
      ),
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: activeTheme.surfaceHeaderBg(isDark),
              border: Border(bottom: BorderSide(color: activeTheme.borderColor(isDark))),
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: activeTheme.accentColor(isDark),
                    child: Icon(c.kind == 'channel' ? Icons.tag : Icons.person, size: 36, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    c.name ?? 'Conversation',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    c.topic ?? 'No topic set',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Kind'),
                  subtitle: Text(c.kind.toUpperCase()),
                ),
                ListTile(
                  leading: const Icon(Icons.tag),
                  title: const Text('Messages in Conversation'),
                  subtitle: Text('${chatState.getMessages(c.id).length} messages'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
