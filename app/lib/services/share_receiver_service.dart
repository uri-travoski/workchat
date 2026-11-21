import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/conversation.dart';
import '../state/chat_state.dart';
import '../ui/screens/mobile_chat_screen.dart';

class SharedContent {
  final String? text;
  final List<File> files;

  SharedContent({this.text, required this.files});

  bool get isEmpty => (text == null || text!.trim().isEmpty) && files.isEmpty;
  bool get isNotEmpty => !isEmpty;
}

class ShareReceiverService {
  static const MethodChannel _channel = MethodChannel('com.workchat.workchat/share');

  static void init(BuildContext context) {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedContentReceived' && call.arguments is Map) {
        final content = _parseSharedContent(Map<String, dynamic>.from(call.arguments as Map));
        if (content.isNotEmpty && context.mounted) {
          _handleIncomingShare(context, content);
        }
      }
    });

    // Check for initial launch share
    checkInitialShare(context);
  }

  static Future<void> checkInitialShare(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      final res = await _channel.invokeMethod<Map>('getSharedContent');
      if (res != null && context.mounted) {
        final content = _parseSharedContent(Map<String, dynamic>.from(res));
        if (content.isNotEmpty && context.mounted) {
          _handleIncomingShare(context, content);
        }
      }
    } catch (_) {}
  }

  static SharedContent _parseSharedContent(Map<String, dynamic> data) {
    final text = data['text'] as String?;
    final rawFiles = data['files'] as List<dynamic>? ?? [];
    final files = <File>[];

    for (final item in rawFiles) {
      if (item is Map && item['path'] != null) {
        final f = File(item['path'] as String);
        if (f.existsSync()) {
          files.add(f);
        }
      }
    }

    return SharedContent(text: text, files: files);
  }

  static void _handleIncomingShare(BuildContext context, SharedContent content) {
    final chatState = context.read<ChatState?>();
    if (chatState == null || chatState.conversations.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.share_rounded, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          content.files.isNotEmpty
                              ? 'Share ${content.files.length} ${content.files.length == 1 ? "file" : "files"} to...'
                              : 'Share text to...',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                if (content.files.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        content.files.map((f) => f.path.split(Platform.pathSeparator).last).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: chatState.conversations.length,
                    itemBuilder: (cCtx, idx) {
                      final c = chatState.conversations[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(c.kind == 'channel' ? Icons.tag : Icons.person, size: 18),
                        ),
                        title: Text(c.name ?? 'Chat', maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(c.topic ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.send_rounded, size: 18, color: Color(0xFF38BDF8)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _sendSharedContentToConv(context, c, content, chatState);
                        },
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

  static void _sendSharedContentToConv(
    BuildContext context,
    Conversation conv,
    SharedContent content,
    ChatState chatState,
  ) {
    chatState.selectConversation(conv);
    chatState.sendMessage(content.text ?? '', files: content.files);

    if (Platform.isAndroid || Platform.isIOS) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MobileChatScreen(conversation: conv),
        ),
      ).then((_) {
        chatState.selectConversation(null);
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Shared to #${conv.name ?? "Chat"}')),
    );
  }
}
