import 'dart:io';
import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/ws_service.dart';

class ChatState extends ChangeNotifier {
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

      if (_conversations.isNotEmpty && _activeConv == null) {
        selectConversation(_conversations.first);
      }
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  Future<void> selectConversation(Conversation conv) async {
    _activeConv = conv;
    _activeThreadRoot = null;
    conv.unreadCount = 0;
    notifyListeners();

    if (!_messagesByConv.containsKey(conv.id)) {
      final msgs = await api.fetchHistory(conv.id);
      _messagesByConv[conv.id] = msgs;
      notifyListeners();
    }

    if (conv.lastSeq > 0) {
      api.markRead(conv.id, conv.lastSeq);
    }
  }

  void openThread(Message rootMessage) async {
    _activeThreadRoot = rootMessage;
    _threadMessages = [];
    notifyListeners();

    if (_activeConv != null) {
      _threadMessages = await api.fetchThreadMessages(_activeConv!.id, rootMessage.id);
      notifyListeners();
    }
  }

  void closeThread() {
    _activeThreadRoot = null;
    _threadMessages = [];
    notifyListeners();
  }

  Future<void> sendMessage(String text, {List<File> files = const []}) async {
    if (_activeConv == null || (text.trim().isEmpty && files.isEmpty)) return;

    List<String> attachmentIds = [];
    for (final f in files) {
      final name = f.path.split(Platform.pathSeparator).last;
      final att = await api.uploadFile(f, name);
      attachmentIds.add(att.id);
    }

    final sentMsg = await api.sendMessage(
      convId: _activeConv!.id,
      body: text,
      threadRoot: _activeThreadRoot?.id,
      attachmentIds: attachmentIds,
    );

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
    await api.addReaction(messageId, emoji);
    // Optimistic reaction update
    if (_activeConv != null) {
      final list = _messagesByConv[_activeConv!.id];
      if (list != null) {
        final msg = list.firstWhere((m) => m.id == messageId, orElse: () => list.first);
        msg.reactions = [...msg.reactions, Reaction(emoji: emoji, userId: currentUserId)];
        notifyListeners();
      }
    }
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
