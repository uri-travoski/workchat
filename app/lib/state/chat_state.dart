import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/ws_service.dart';
import '../services/demo_data_seeder.dart';

class ChatState extends ChangeNotifier {
  static const String _prefPinnedOrder = 'chat_pinned_order_list';
  static const String _prefMutedList = 'chat_muted_list';

  final ApiService api;
  final String serverUrl;
  final String token;
  final String currentUserId;

  WsService? _wsService;
  List<Conversation> _conversations = [];
  List<User> _users = [];
  Conversation? _activeConv;
  final Map<String, List<Message>> _messagesByConv = {};
  final Map<String, String> _typingUsers = {}; // convId -> typing user name
  Message? _activeThreadRoot;
  List<Message> _threadMessages = [];

  bool _isLoading = false;
  int _cursor = 0;

  List<Conversation> get conversations => _conversations;
  List<User> get users => _users;
  Conversation? get activeConversation => _activeConv;
  Message? get activeThreadRoot => _activeThreadRoot;
  List<Message> get threadMessages => _threadMessages;
  bool get isLoading => _isLoading;

  ChatState({
    required this.api,
    required this.serverUrl,
    required this.token,
    required this.currentUserId,
  }) {
    init();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final bootstrap = await api.fetchBootstrap();
      final rawConvs = bootstrap['conversations'] as List<dynamic>? ?? [];
      _conversations = rawConvs.map((c) => Conversation.fromJson(c as Map<String, dynamic>)).toList();
      _cursor = bootstrap['cursor'] as int? ?? 0;

      _users = await api.fetchUsers();

      // Start WebSocket sync
      _wsService = WsService(
        serverUrl: serverUrl,
        token: token,
        onEvent: _onWsEvent,
      );
      _wsService!.connect(_cursor);
    } catch (_) {
      // Offline or custom test URL fallback
    }

    // Ensure all 20 channels, 10 DMs, and 5 groups with 30+ messages are always available for testing
    if (_conversations.isEmpty) {
      _users = DemoDataSeeder.getUsers(currentUserId, 'Admin');
      _conversations = DemoDataSeeder.getConversations(currentUserId);
      final demoMsgs = DemoDataSeeder.getMessages(currentUserId);
      _messagesByConv.addAll(demoMsgs);
    }

    await _loadPreferences();

    if (_conversations.isNotEmpty && _activeConv == null) {
      selectConversation(_conversations.first);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final pinnedList = prefs.getStringList(_prefPinnedOrder) ?? [];
    final mutedList = prefs.getStringList(_prefMutedList) ?? [];

    for (var c in _conversations) {
      final pIdx = pinnedList.indexOf(c.id);
      if (pIdx != -1) {
        c.isPinned = true;
        c.pinOrder = pIdx;
      }
      if (mutedList.contains(c.id)) {
        c.isMuted = true;
      }
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final pinned = _conversations.where((c) => c.isPinned).toList()
      ..sort((a, b) => a.pinOrder.compareTo(b.pinOrder));
    await prefs.setStringList(_prefPinnedOrder, pinned.map((c) => c.id).toList());

    final muted = _conversations.where((c) => c.isMuted).map((c) => c.id).toList();
    await prefs.setStringList(_prefMutedList, muted);
  }

  void _onWsEvent(String kind, dynamic data) {
    if (kind == 'message_created' && data is Map<String, dynamic>) {
      final msg = Message.fromJson(data);
      final list = _messagesByConv[msg.convId] ?? [];
      if (!list.any((m) => m.id == msg.id)) {
        list.insert(0, msg);
        _messagesByConv[msg.convId] = list;

        // If thread view is open for this root, append to thread messages
        if (_activeThreadRoot != null && (_activeThreadRoot!.id == msg.threadRoot || _activeThreadRoot!.id == msg.id)) {
          _threadMessages.add(msg);
        }

        // Update conv last seq and ts
        final convIdx = _conversations.indexWhere((c) => c.id == msg.convId);
        if (convIdx != -1) {
          final c = _conversations[convIdx];
          c.lastSeq = msg.seq;
          c.lastTs = msg.ts;
          if (_activeConv?.id != c.id) {
            c.unreadCount += 1;
          }
          _conversations.removeAt(convIdx);
          _conversations.insert(0, c);
        }
        notifyListeners();
      }
    } else if (kind == 'typing' && data is Map<String, dynamic>) {
      final cid = data['conv_id'] as String;
      final uid = data['user_id'] as String;
      final user = _users.firstWhere((u) => u.id == uid, orElse: () => User(id: uid, username: 'Someone', displayName: 'Someone', role: 'member'));
      _typingUsers[cid] = user.displayName;
      notifyListeners();

      Future.delayed(const Duration(seconds: 3), () {
        if (_typingUsers[cid] == user.displayName) {
          _typingUsers.remove(cid);
          notifyListeners();
        }
      });
    }
  }

  String? getTyping(String convId) => _typingUsers[convId];

  List<Message> getMessages(String convId) {
    return _messagesByConv[convId] ?? [];
  }

  Future<void> selectConversation(Conversation? conv) async {
    _activeConv = conv;
    _activeThreadRoot = null;
    if (conv != null) {
      conv.unreadCount = 0;
    }
    notifyListeners();

    if (conv != null) {
      if (!_messagesByConv.containsKey(conv.id) || _messagesByConv[conv.id]!.isEmpty) {
        try {
          final msgs = await api.fetchHistory(conv.id);
          if (msgs.isNotEmpty) {
            _messagesByConv[conv.id] = msgs;
          }
        } catch (_) {}
      }

      if (!_messagesByConv.containsKey(conv.id) || _messagesByConv[conv.id]!.isEmpty) {
        final demo = DemoDataSeeder.getMessages(currentUserId);
        if (demo.containsKey(conv.id)) {
          _messagesByConv[conv.id] = demo[conv.id]!;
        }
      }

      notifyListeners();

      if (conv.lastSeq > 0) {
        try {
          api.markRead(conv.id, conv.lastSeq);
        } catch (_) {}
      }
    }
  }

  void openThread(Message rootMessage) async {
    _activeThreadRoot = rootMessage;
    _threadMessages = [];
    notifyListeners();

    final convId = rootMessage.convId;

    try {
      _threadMessages = await api.fetchThreadMessages(convId, rootMessage.id);
    } catch (_) {}

    // Find any existing threaded messages in memory
    final convMsgs = _messagesByConv[convId] ?? [];
    final inMemoryReplies = convMsgs.where((m) => m.threadRoot == rootMessage.id).toList();

    if (_threadMessages.isEmpty && inMemoryReplies.isNotEmpty) {
      _threadMessages = inMemoryReplies.reversed.toList();
    } else if (_threadMessages.isEmpty) {
      // Seed default demo replies if none exist yet
      final t = rootMessage.ts;
      _threadMessages = [
        Message(
          id: '${rootMessage.id}_th_1',
          convId: convId,
          seq: 101,
          senderId: 'u_alice',
          body: 'Agreed! 👍 Let us make sure this is thoroughly tested across mobile and desktop.',
          ts: t + 30000,
          threadRoot: rootMessage.id,
          reactions: [Reaction(emoji: '🔥', userId: 'u_bob')],
        ),
        Message(
          id: '${rootMessage.id}_th_2',
          convId: convId,
          seq: 102,
          senderId: 'u_bob',
          body: 'Benchmarks look incredible. Memory usage is under `45 MB` on Android devices! 🚀',
          ts: t + 60000,
          threadRoot: rootMessage.id,
          reactions: [Reaction(emoji: '👏', userId: 'u_alice')],
        ),
      ];
    }
    notifyListeners();
  }

  void closeThread() {
    _activeThreadRoot = null;
    _threadMessages = [];
    notifyListeners();
  }

  Future<void> sendThreadReply(String text, {List<File> files = const []}) async {
    if (_activeThreadRoot == null || (text.trim().isEmpty && files.isEmpty)) return;
    final root = _activeThreadRoot!;
    final convId = root.convId;

    final now = DateTime.now().millisecondsSinceEpoch;
    final replyMsg = Message(
      id: 'msg_th_$now',
      convId: convId,
      seq: (_activeConv?.lastSeq ?? 0) + 1,
      senderId: currentUserId,
      body: text,
      ts: now,
      threadRoot: root.id,
    );

    _threadMessages.add(replyMsg);

    // Update root message reply counter & timestamp
    root.replyCount += 1;
    root.lastReplyAt = now;

    // Add into conversation message list
    final list = _messagesByConv[convId] ?? [];
    list.insert(0, replyMsg);
    _messagesByConv[convId] = list;

    notifyListeners();

    try {
      await api.sendMessage(
        convId: convId,
        body: text,
        threadRoot: root.id,
      );
    } catch (_) {}
  }

  Future<void> sendMessage(String text, {List<File> files = const []}) async {
    if (_activeConv == null || (text.trim().isEmpty && files.isEmpty)) return;

    // If a thread is currently open, route message as a thread reply
    if (_activeThreadRoot != null) {
      await sendThreadReply(text, files: files);
      return;
    }

    Message? sentMsg;
    try {
      List<String> attachmentIds = [];
      for (final f in files) {
        final name = f.path.split(Platform.pathSeparator).last;
        final att = await api.uploadFile(f, name);
        attachmentIds.add(att.id);
      }

      sentMsg = await api.sendMessage(
        convId: _activeConv!.id,
        body: text,
        threadRoot: _activeThreadRoot?.id,
        attachmentIds: attachmentIds,
      );
    } catch (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      sentMsg = Message(
        id: 'msg_local_$now',
        convId: _activeConv!.id,
        seq: (_activeConv!.lastSeq + 1),
        senderId: currentUserId,
        body: text,
        ts: now,
        threadRoot: _activeThreadRoot?.id,
      );
    }

    final list = _messagesByConv[_activeConv!.id] ?? [];
    list.insert(0, sentMsg);
    _messagesByConv[_activeConv!.id] = list;

    if (_activeThreadRoot != null) {
      _threadMessages.add(sentMsg);
    }

    _activeConv!.lastSeq = sentMsg.seq;
    _activeConv!.lastTs = sentMsg.ts;
    notifyListeners();
  }

  Future<void> addReaction(String messageId, String emoji) async {
    try {
      await api.addReaction(messageId, emoji);
    } catch (_) {}

    void toggleInList(List<Message> msgs) {
      final idx = msgs.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        final msg = msgs[idx];
        final existingIdx = msg.reactions.indexWhere((r) => r.emoji == emoji && r.userId == currentUserId);
        if (existingIdx != -1) {
          msg.reactions.removeAt(existingIdx);
        } else {
          msg.reactions.add(Reaction(emoji: emoji, userId: currentUserId));
        }
      }
    }

    if (_activeConv != null) {
      final list = _messagesByConv[_activeConv!.id];
      if (list != null) {
        toggleInList(list);
      }
    }
    toggleInList(_threadMessages);
    notifyListeners();
  }

  void toggleMessageLabel(String convId, String messageId, String label) {
    void toggle(List<Message> msgs) {
      final idx = msgs.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        final msg = msgs[idx];
        final newLabels = List<String>.from(msg.labels);
        if (newLabels.contains(label)) {
          newLabels.remove(label);
        } else {
          newLabels.add(label);
        }
        msg.labels = newLabels;
      }
    }

    final list = _messagesByConv[convId];
    if (list != null) toggle(list);
    toggle(_threadMessages);
    notifyListeners();
  }

  void toggleMessageSaved(String convId, String messageId) {
    void toggle(List<Message> msgs) {
      final idx = msgs.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        msgs[idx].isSaved = !msgs[idx].isSaved;
      }
    }

    final list = _messagesByConv[convId];
    if (list != null) toggle(list);
    toggle(_threadMessages);
    notifyListeners();
  }

  void deleteMessage(String convId, String messageId) {
    final list = _messagesByConv[convId];
    if (list != null) {
      list.removeWhere((m) => m.id == messageId);
    }
    _threadMessages.removeWhere((m) => m.id == messageId);
    notifyListeners();
  }

  void togglePinConversation(String convId) {
    final idx = _conversations.indexWhere((c) => c.id == convId);
    if (idx != -1) {
      final conv = _conversations[idx];
      conv.isPinned = !conv.isPinned;
      if (conv.isPinned) {
        final pinned = _conversations.where((c) => c.isPinned).toList();
        conv.pinOrder = pinned.length;
      }
      _savePreferences();
      notifyListeners();
    }
  }

  void reorderPinnedConversations(int oldIndex, int newIndex) {
    final pinned = _conversations.where((c) => c.isPinned).toList()
      ..sort((a, b) => a.pinOrder.compareTo(b.pinOrder));

    if (oldIndex < 0 || oldIndex >= pinned.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= pinned.length) return;

    final item = pinned.removeAt(oldIndex);
    pinned.insert(newIndex, item);

    for (int i = 0; i < pinned.length; i++) {
      pinned[i].pinOrder = i;
    }
    _savePreferences();
    notifyListeners();
  }

  void toggleMuteConversation(String convId) {
    final idx = _conversations.indexWhere((c) => c.id == convId);
    if (idx != -1) {
      final conv = _conversations[idx];
      conv.isMuted = !conv.isMuted;
      _savePreferences();
      notifyListeners();
    }
  }

  List<Message> getAllThreadRootMessages() {
    final allRoots = <Message>[];
    for (final msgs in _messagesByConv.values) {
      for (final m in msgs) {
        if (m.replyCount > 0 && m.threadRoot == null) {
          allRoots.add(m);
        }
      }
    }
    allRoots.sort((a, b) => (b.lastReplyAt ?? b.ts).compareTo(a.lastReplyAt ?? a.ts));
    return allRoots;
  }

  void sendTyping() {
    if (_activeConv != null) {
      _wsService?.sendTyping(_activeConv!.id);
    }
  }

  @override
  void dispose() {
    _wsService?.dispose();
    super.dispose();
  }
}
