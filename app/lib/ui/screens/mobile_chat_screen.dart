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
import 'thread_view.dart';

class MobileChatScreen extends StatefulWidget {
  final Conversation conversation;

  const MobileChatScreen({super.key, required this.conversation});

  @override
  State<MobileChatScreen> createState() => _MobileChatScreenState();
}

class _MobileChatScreenState extends State<MobileChatScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<int> _matchedIndices = [];
  int _currentMatchPointer = 0;

  String? _selectedMessageLabel;
  bool _filterOnlySaved = false;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query, List<Message> messages) {
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
      _currentMatchPointer = 0;
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
    final isHidden = hiddenMgr.isHidden(widget.conversation.id);

    var messages = chatState.getMessages(widget.conversation.id);
    final usersMap = {for (var u in chatState.users) u.id: u};
    final typingUser = chatState.getTyping(widget.conversation.id);

    // Apply inside-conversation filters
    if (_selectedMessageLabel != null) {
      messages = messages.where((m) => m.labels.contains(_selectedMessageLabel)).toList();
    }
    if (_filterOnlySaved) {
      messages = messages.where((m) => m.isSaved).toList();
    }

    return Scaffold(
      backgroundColor: activeTheme.chatStageBg(isDark),
      appBar: _isSearching
          ? _buildSearchAppBar(messages, activeTheme, isDark)
          : _buildNormalAppBar(context, isHidden, hiddenMgr, typingUser, chatState, activeTheme, isDark),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Filter banner
            if (_selectedMessageLabel != null || _filterOnlySaved)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFF59E0B).withOpacity(0.18),
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt_rounded, size: 18, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedMessageLabel != null
                            ? 'Filtered by #$_selectedMessageLabel (${messages.length} messages)'
                            : 'Filtered by Saved (${messages.length} messages)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedMessageLabel = null;
                          _filterOnlySaved = false;
                        });
                      },
                      child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold)),
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
                            _openThreadSheet(context, m, chatState);
                          },
                          onAddReaction: (emoji) {
                            chatState.addReaction(m.id, emoji);
                          },
                          onToggleLabel: (label) {
                            chatState.toggleMessageLabel(widget.conversation.id, m.id, label);
                          },
                          onToggleSaved: () {
                            chatState.toggleMessageSaved(widget.conversation.id, m.id);
                          },
                          onDelete: () {
                            chatState.deleteMessage(widget.conversation.id, m.id);
                          },
                        );
                      },
                    ),
            ),

            // Composer with formatting toolbar
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
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar(
    BuildContext context,
    bool isHidden,
    HiddenChatManager hiddenMgr,
    String? typingUser,
    ChatState chatState,
    dynamic activeTheme,
    bool isDark,
  ) {
    return AppBar(
      backgroundColor: activeTheme.surfaceHeaderBg(isDark),
      elevation: 1,
      toolbarHeight: 60,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Back to conversations',
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  widget.conversation.name ?? 'Conversation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
          else if (widget.conversation.topic != null && widget.conversation.topic!.isNotEmpty)
            Text(
              widget.conversation.topic!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          tooltip: 'Search in conversation',
          onPressed: () {
            setState(() {
              _isSearching = true;
              _matchedIndices = [];
              _currentMatchPointer = 0;
            });
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          tooltip: 'Chat Options',
          onSelected: (value) {
            if (value == 'lock_chat') {
              if (!hiddenMgr.hasPin) {
                showDialog(context: context, builder: (_) => const HiddenLockDialog());
              } else {
                hiddenMgr.toggleHidden(widget.conversation.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(hiddenMgr.isHidden(widget.conversation.id) ? 'Chat marked as Hidden' : 'Chat unhidden')),
                );
              }
            } else if (value == 'filter_label') {
              _showFilterByLabelDialog(context, chatState);
            } else if (value == 'filter_saved') {
              setState(() => _filterOnlySaved = !_filterOnlySaved);
            } else if (value == 'view_threads') {
              _showConversationThreadsDrawer(context, chatState);
            } else if (value == 'chat_info') {
              _showChatInfoDialog(context, chatState);
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'lock_chat',
              child: Row(
                children: [
                  Icon(isHidden ? Icons.lock_open_rounded : Icons.lock_outline_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(isHidden ? 'Unlock / Unhide Chat' : 'Lock / Hide with PIN'),
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
                  Text(_filterOnlySaved ? 'Show All Messages' : 'Filter by Saved'),
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
    );
  }

  PreferredSizeWidget _buildSearchAppBar(List<Message> messages, dynamic activeTheme, bool isDark) {
    final matchCount = _matchedIndices.length;
    final currentPos = matchCount > 0 ? _currentMatchPointer + 1 : 0;

    return AppBar(
      backgroundColor: activeTheme.surfaceHeaderBg(isDark),
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          setState(() {
            _isSearching = false;
            _searchController.clear();
            _matchedIndices = [];
            _currentMatchPointer = 0;
          });
        },
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Search messages...',
          border: InputBorder.none,
        ),
        onChanged: (val) => _onSearchChanged(val, messages),
      ),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              matchCount > 0 ? '$currentPos of $matchCount' : '0 found',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
          tooltip: 'Previous match',
          onPressed: matchCount > 0 ? _jumpToPrevMatch : null,
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          tooltip: 'Next match',
          onPressed: matchCount > 0 ? _jumpToNextMatch : null,
        ),
      ],
    );
  }

  void _openThreadSheet(BuildContext context, Message m, ChatState chatState) {
    chatState.openThread(m);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.88,
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

  void _showFilterByLabelDialog(BuildContext context, ChatState chatState) {
    final messages = chatState.getMessages(widget.conversation.id);
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
              Text('Filter by Label'),
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

  void _showConversationThreadsDrawer(BuildContext context, ChatState chatState) {
    final messages = chatState.getMessages(widget.conversation.id);
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
                      'Threads in #${widget.conversation.name ?? "chat"}',
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
                                  _openThreadSheet(context, tm, chatState);
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

  void _showChatInfoDialog(BuildContext context, ChatState chatState) {
    final c = widget.conversation;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(c.name ?? 'Conversation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Topic: ${c.topic ?? "None"}', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              Text('Type: ${c.kind.toUpperCase()}', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              Text('Messages: ${chatState.getMessages(c.id).length}', style: const TextStyle(fontSize: 13)),
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
}
